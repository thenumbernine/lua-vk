-- helper not wrapper
local ffi = require 'ffi'
local class = require 'ext.class'
local asserteq = require 'ext.assert'.eq
local vector = require 'ffi.cpp.vector-lua'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local VulkanDeviceMemoryImage = require 'vk.vulkandevicememoryimage'
local VKSwapchain = require 'vk.swapchain'


local uint32_t = ffi.typeof'uint32_t'
local VkAttachmentDescription = ffi.typeof'VkAttachmentDescription'
local VkFramebuffer = ffi.typeof'VkFramebuffer'
local VkImageView = ffi.typeof'VkImageView'
local VkRenderPass = ffi.typeof'VkRenderPass'
local VkSubpassDescription_1 = ffi.typeof'VkSubpassDescription[1]'
local VkSubpassDependency_1 = ffi.typeof'VkSubpassDependency[1]'
local VkFramebufferCreateInfo_1 = ffi.typeof'VkFramebufferCreateInfo[1]'
local VkExtent2D = ffi.typeof'VkExtent2D'
local VkImageViewCreateInfo_1 = ffi.typeof'VkImageViewCreateInfo[1]'
local VkAttachmentReference_1 = ffi.typeof'VkAttachmentReference[1]'
local VkRenderPassCreateInfo_1 = ffi.typeof'VkRenderPassCreateInfo[1]'


local VulkanSwapchain = class()

function VulkanSwapchain:init(width, height, physDev, device, surface, msaaSamples)
	self.width = width
	self.height = height

	local swapChainSupport = physDev:querySwapChainSupport(nil, surface)
	self.extent = self:chooseSwapExtent(width, height, swapChainSupport.capabilities)

	local imageCount = swapChainSupport.capabilities.minImageCount + 1
	if swapChainSupport.capabilities.maxImageCount > 0 then
		imageCount = math.min(imageCount, swapChainSupport.capabilities.maxImageCount)
	end

	local surfaceFormat = self:chooseSwapSurfaceFormat(swapChainSupport.formats)
	local presentMode = self:chooseSwapPresentMode(swapChainSupport.presentModes)

	local info = {}
	info.surface = surface.id
	info.minImageCount = imageCount
	info.imageFormat = surfaceFormat.format
	info.imageColorSpace = surfaceFormat.colorSpace
	info.imageExtent = self.extent
	info.imageArrayLayers = 1
	info.imageUsage = vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT
	info.preTransform = swapChainSupport.capabilities.currentTransform
	info.compositeAlpha = vk.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR
	info.presentMode = presentMode
	info.clipped = vk.VK_TRUE
	local indices = physDev:findQueueFamilies(nil, surface)
	self.queueFamilyIndices = vector(uint32_t)
	for index in pairs{
		[indices.graphicsFamily] = true,
		[indices.presentFamily] = true,
	} do
		self.queueFamilyIndices:emplace_back()[0] = index
	end
	if indices.graphicsFamily ~= indices.presentFamily then
		info.imageSharingMode = vk.VK_SHARING_MODE_CONCURRENT
		info.queueFamilyIndexCount = #self.queueFamilyIndices
		info.pQueueFamilyIndices = self.queueFamilyIndices.v
	else
		info.imageSharingMode = vk.VK_SHARING_MODE_EXCLUSIVE
	end
	info.device = device
	self.obj = VKSwapchain(info)
	self.queueFamilyIndices = nil

	self.images = self.obj:getImages(device)

	local numImageViews = #self.images
	self.imageViews = ffi.new(ffi.typeof('$[?]', VkImageView), numImageViews)
	for i=0,#self.images-1 do
		self.imageViews[i] = self:createImageView(
			device.id,
			self.images.v[i],
			surfaceFormat.format,
			vk.VK_IMAGE_ASPECT_COLOR_BIT,
			1
		)
	end

	self.renderPass = self:createRenderPass(physDev, device.id, surfaceFormat.format, msaaSamples)

	local colorFormat = surfaceFormat.format

	self.colorImageAndMemory = VulkanDeviceMemoryImage:createImage(
		physDev,
		device.id,
		width,
		height,
		1,
		msaaSamples,
		colorFormat,
		vk.VK_IMAGE_TILING_OPTIMAL,
		bit.bor(vk.VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT, vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT),
		vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
	)

	self.colorImageView = self:createImageView(
		device.id,
		self.colorImageAndMemory.image,
		colorFormat,
		vk.VK_IMAGE_ASPECT_COLOR_BIT,
		1
	)

	local depthFormat = physDev:findDepthFormat()

	self.depthImageAndMemory = VulkanDeviceMemoryImage:createImage(
		physDev,
		device.id,
		width,
		height,
		1,
		msaaSamples,
		depthFormat,
		vk.VK_IMAGE_TILING_OPTIMAL,
		vk.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
		vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
	)
	self.depthImageView = self:createImageView(
		device.id,
		self.depthImageAndMemory.image,
		depthFormat,
		vk.VK_IMAGE_ASPECT_DEPTH_BIT,
		1
	)

	self.framebuffers = vector(VkFramebuffer, numImageViews)
	for i=0,numImageViews-1 do
		local numAttachments = 3
		self.attachments = ffi.new(ffi.typeof('$[?]', VkImageView), numAttachments)
		self.attachments[0] = self.colorImageView
		self.attachments[1] = self.depthImageView
		self.attachments[2] = self.imageViews[i]
		self.info = VkFramebufferCreateInfo_1()
		self.info[0].sType = vk.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO
		self.info[0].renderPass = self.renderPass
		self.info[0].attachmentCount = numAttachments
		self.info[0].pAttachments = self.attachments
		self.info[0].width = width
		self.info[0].height = height
		self.info[0].layers = 1
		self.framebuffers.v[i] = vkGet(
			VkFramebuffer,
			vkassert,
			vk.vkCreateFramebuffer,
			device.id,
			self.info,
			nil
		)
		self.info = nil
		self.attachments = nil
	end
end

function VulkanSwapchain:chooseSwapExtent(width, height, capabilities)
	if capabilities.currentExtent.width ~= -1 then
		return VkExtent2D(capabilities.currentExtent)
	else
		local actualExtent = VkExtent2D(width, height)
		actualExtent.width = math.clamp(actualExtent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width)
		actualExtent.height = math.clamp(actualExtent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height)
		return actualExtent
	end
end

function VulkanSwapchain:chooseSwapSurfaceFormat(availableFormats)
	for i=0,#availableFormats-1 do
		local format = availableFormats.v[i]
		if format.format == vk.VK_FORMAT_B8G8R8A8_SRGB
		and format.colorSpace == vk.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR
		then
			return format
		end
	end
	return availableFormats[0]
end

function VulkanSwapchain:chooseSwapPresentMode(availablePresentModes)
	-- return-if-found ... why not just treat this as a set?
	for i=0,#availablePresentModes-1 do
		local presentMode = availablePresentModes.v[i]
		if presentMode == vk.VK_PRESENT_MODE_MAILBOX_KHR then
			return presentMode
		end
	end
	return vk.VK_PRESENT_MODE_FIFO_KHR
end

function VulkanSwapchain:createImageView(device, image, format, aspectFlags, mipLevels)
	self.info = VkImageViewCreateInfo_1()
	self.info[0].sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
	self.info[0].image = image
	self.info[0].viewType = vk.VK_IMAGE_VIEW_TYPE_2D
	self.info[0].format = format
	self.info[0].subresourceRange.aspectMask = aspectFlags
	self.info[0].subresourceRange.levelCount = mipLevels
	self.info[0].subresourceRange.layerCount = 1
	local result = vkGet(
		VkImageView,
		vkassert,
		vk.vkCreateImageView,
		device,
		self.info,
		nil
	)
	self.info = nil
	return result
end

function VulkanSwapchain:createRenderPass(physDev, device, swapChainImageFormat, msaaSamples)
	-- need to keep these from gc'ing until the function is through ...
	local numAttachments = 3
	self.attachments = ffi.new(ffi.typeof('$[?]', VkAttachmentDescription), numAttachments)
	-- colorAttachment
	local v = self.attachments+0
	v.format = swapChainImageFormat
	v.samples = msaaSamples
	v.loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR
	v.storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE
	v.stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE
	v.stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE
	v.initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED
	v.finalLayout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
	v=v+1
	-- depthAttachment
	v.format = physDev:findDepthFormat()
	v.samples = msaaSamples
	v.loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR
	v.storeOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE
	v.stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE
	v.stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE
	v.initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED
	v.finalLayout = vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL
	v=v+1
	-- colorAttachmentResolve
	v.format = swapChainImageFormat
	v.samples = vk.VK_SAMPLE_COUNT_1_BIT
	v.loadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE
	v.storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE
	v.stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE
	v.stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE
	v.initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED
	v.finalLayout = vk.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
	v=v+1
	asserteq(v, self.attachments + numAttachments)

	self.colorAttachmentRef = VkAttachmentReference_1()
	self.colorAttachmentRef[0].attachment = 0
	self.colorAttachmentRef[0].layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
	self.depthAttachmentRef = VkAttachmentReference_1()
	self.depthAttachmentRef[0].attachment = 1
	self.depthAttachmentRef[0].layout = vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL
	self.colorAttachmentResolveRef = VkAttachmentReference_1()
	self.colorAttachmentResolveRef[0].attachment = 2
	self.colorAttachmentResolveRef[0].layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL

	self.subpasses = VkSubpassDescription_1()
	self.subpasses[0].pipelineBindPoint = vk.VK_PIPELINE_BIND_POINT_GRAPHICS
	self.subpasses[0].colorAttachmentCount = 1
	self.subpasses[0].pColorAttachments = self.colorAttachmentRef
	self.subpasses[0].pResolveAttachments = self.colorAttachmentResolveRef
	self.subpasses[0].pDepthStencilAttachment = self.depthAttachmentRef

	self.dependencies = VkSubpassDependency_1()
	self.dependencies[0].srcSubpass = vk.VK_SUBPASS_EXTERNAL
	self.dependencies[0].dstSubpass = 0
	self.dependencies[0].srcStageMask = bit.bor(
		vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
		vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT
	)
	self.dependencies[0].dstStageMask = bit.bor(
		vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
		vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT
	)
	self.dependencies[0].srcAccessMask = 0
	self.dependencies[0].dstAccessMask = bit.bor(
		vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
		vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT
	)

	self.info = VkRenderPassCreateInfo_1()
	self.info[0].sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO
	self.info[0].attachmentCount = numAttachments
	self.info[0].pAttachments = self.attachments
	self.info[0].subpassCount = 1
	self.info[0].pSubpasses = self.subpasses
	self.info[0].dependencyCount = 1
	self.info[0].pDependencies = self.dependencies

	local result = vkGet(
		VkRenderPass,
		vkassert,
		vk.vkCreateRenderPass,
		device,
		self.info,
		nil
	)

	self.info = nil
	self.dependencies = nil
	self.subpasses = nil
	self.colorAttachmentResolveRef = nil
	self.depthAttachmentRef = nil
	self.colorAttachmentRef = nil
	self.attachments = nil

	return result
end

return VulkanSwapchain
