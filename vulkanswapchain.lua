-- helper not wrapper
local ffi = require 'ffi'
local class = require 'ext.class'
local table = require 'ext.table'
local asserteq = require 'ext.assert'.eq
local vk = require 'vk'
local countof = require 'vk.util'.countof
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor
local VulkanDeviceMemoryImage = require 'vk.vulkandevicememoryimage'
local VKSwapchain = require 'vk.swapchain'


local uint32_t = ffi.typeof'uint32_t'
local uint32_t_array = ffi.typeof'uint32_t[?]'
local VkAttachmentDescription_array = ffi.typeof'VkAttachmentDescription[?]'
local VkAttachmentReference = ffi.typeof'VkAttachmentReference'
local VkExtent2D = ffi.typeof'VkExtent2D'
local VkFramebuffer = ffi.typeof'VkFramebuffer'
local VkFramebuffer_array = ffi.typeof'VkFramebuffer[?]'
local VkImageView = ffi.typeof'VkImageView'
local VkImageView_array = ffi.typeof'VkImageView[?]'
local VkRenderPass = ffi.typeof'VkRenderPass'
local VkSubpassDependency = ffi.typeof'VkSubpassDependency'
local VkSubpassDescription = ffi.typeof'VkSubpassDescription'


local makeVkFramebufferCreateInfo = makeStructCtor'VkFramebufferCreateInfo'
local makeVkImageViewCreateInfo = makeStructCtor'VkImageViewCreateInfo'
local makeVkRenderPassCreateInfo = makeStructCtor'VkRenderPassCreateInfo'


local VulkanSwapchain = class()

function VulkanSwapchain:init(width, height, physDev, device, surface, msaaSamples)
	self.width = width
	self.height = height

	local VKDevice = require 'vk.device'
	if VKDevice:isa(device) then device = device.id end
	self.device = device

	local swapChainSupport = physDev:querySwapChainSupport(nil, surface)
	self.extent = self:chooseSwapExtent(width, height, swapChainSupport.capabilities)

	local imageCount = swapChainSupport.capabilities.minImageCount + 1
	if swapChainSupport.capabilities.maxImageCount > 0 then
		imageCount = math.min(imageCount, swapChainSupport.capabilities.maxImageCount)
	end

	local surfaceFormat = self:chooseSwapSurfaceFormat(swapChainSupport.formats)
	local presentMode = self:chooseSwapPresentMode(swapChainSupport.presentModes)

	local indices = physDev:findQueueFamilies(nil, surface)
	indices = table.keys{
		[indices.graphicsFamily] = true,
		[indices.presentFamily] = true,
	}
	local queueFamilyIndices = uint32_t_array(#indices, indices)

	local familiesDiffer = (indices.graphicsFamily ~= indices.presentFamily) or nil
	self.obj = VKSwapchain{
		device = device,
		surface = surface.id,
		minImageCount = imageCount,
		imageFormat = surfaceFormat.format,
		imageColorSpace = surfaceFormat.colorSpace,
		imageExtent = self.extent,
		imageArrayLayers = 1,
		imageUsage = vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
		preTransform = swapChainSupport.capabilities.currentTransform,
		compositeAlpha = vk.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
		presentMode = presentMode,
		clipped = vk.VK_TRUE,
		imageSharingMode = familiesDiffer and vk.VK_SHARING_MODE_CONCURRENT or vk.VK_SHARING_MODE_EXCLUSIVE,
		queueFamilyIndexCount = familiesDiffer and countof(queueFamilyIndices),
		pQueueFamilyIndices = familiesDiffer and queueFamilyIndices,
	}

	self.images = self.obj:getImages()

	local numImageViews = #self.images
	self.imageViews = VkImageView_array(numImageViews)
	for i=0,numImageViews-1 do
		self.imageViews[i] = self:createImageView(
			device,
			self.images.v[i],
			surfaceFormat.format,
			vk.VK_IMAGE_ASPECT_COLOR_BIT,
			1
		)
	end

	self.renderPass = self:createRenderPass(physDev, device, surfaceFormat.format, msaaSamples)

	local colorFormat = surfaceFormat.format

	self.colorImageAndMemory = VulkanDeviceMemoryImage:createImage(
		physDev,
		device,
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
		device,
		self.colorImageAndMemory.image,
		colorFormat,
		vk.VK_IMAGE_ASPECT_COLOR_BIT,
		1
	)

	local depthFormat = physDev:findDepthFormat()

	self.depthImageAndMemory = VulkanDeviceMemoryImage:createImage(
		physDev,
		device,
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
		device,
		self.depthImageAndMemory.image,
		depthFormat,
		vk.VK_IMAGE_ASPECT_DEPTH_BIT,
		1
	)

	self.framebuffers = VkFramebuffer_array(numImageViews)
	for i=0,numImageViews-1 do
		local numAttachments = 3
		local attachments = VkImageView_array(numAttachments)
		attachments[0] = self.colorImageView
		attachments[1] = self.depthImageView
		attachments[2] = self.imageViews[i]
		self.framebuffers[i] = vkGet(
			VkFramebuffer,
			vkassert,
			vk.vkCreateFramebuffer,
			device,
			makeVkFramebufferCreateInfo{
				renderPass = self.renderPass,
				attachmentCount = numAttachments,
				pAttachments = attachments,
				width = width,
				height = height,
				layers = 1,
			},
			nil
		)
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
	return vkGet(
		VkImageView,
		vkassert,
		vk.vkCreateImageView,
		device,
		makeVkImageViewCreateInfo{
			image = image,
			viewType = vk.VK_IMAGE_VIEW_TYPE_2D,
			format = format,
			subresourceRange = {
				aspectMask = aspectFlags,
				levelCount = mipLevels,
				layerCount = 1,
			},
		},
		nil
	)
end

function VulkanSwapchain:createRenderPass(physDev, device, swapChainImageFormat, msaaSamples)
	-- need to keep these from gc'ing until the function is through ...
	local numAttachments = 3
	local attachments = VkAttachmentDescription_array(numAttachments)
	-- colorAttachment
	local v = attachments+0
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
	asserteq(v, attachments + numAttachments)

	local colorAttachmentRef = VkAttachmentReference()
	colorAttachmentRef.attachment = 0
	colorAttachmentRef.layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
	local depthAttachmentRef = VkAttachmentReference()
	depthAttachmentRef.attachment = 1
	depthAttachmentRef.layout = vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL
	local colorAttachmentResolveRef = VkAttachmentReference()
	colorAttachmentResolveRef.attachment = 2
	colorAttachmentResolveRef.layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL

	local subpasses = VkSubpassDescription()
	subpasses.pipelineBindPoint = vk.VK_PIPELINE_BIND_POINT_GRAPHICS
	subpasses.colorAttachmentCount = 1
	subpasses.pColorAttachments = colorAttachmentRef
	subpasses.pResolveAttachments = colorAttachmentResolveRef
	subpasses.pDepthStencilAttachment = depthAttachmentRef

	local dependencies = VkSubpassDependency()
	dependencies.srcSubpass = vk.VK_SUBPASS_EXTERNAL
	dependencies.dstSubpass = 0
	dependencies.srcStageMask = bit.bor(
		vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
		vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT
	)
	dependencies.dstStageMask = bit.bor(
		vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
		vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT
	)
	dependencies.srcAccessMask = 0
	dependencies.dstAccessMask = bit.bor(
		vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
		vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT
	)

	return vkGet(
		VkRenderPass,
		vkassert,
		vk.vkCreateRenderPass,
		device,
		makeVkRenderPassCreateInfo{
			attachmentCount = numAttachments,
			pAttachments = attachments,
			subpassCount = 1,
			pSubpasses = subpasses,
			dependencyCount = 1,
			pDependencies = dependencies,
		},
		nil
	)
end

function VulkanSwapchain:destroy()
	if self.framebuffers then
		for i=0,countof(self.framebuffers)-1 do
			vk.vkDestroyFramebuffer(self.device, self.framebuffers[i], nil)
		end
	end
	self.framebuffers = nil

	if self.imageViews then
		for i=0,countof(self.imageViews)-1 do
			vk.vkDestroyImageView(self.device, self.imageViews[i], nil)
		end
	end
	self.imageViews = nil
	self.images = nil

	if self.renderPass then
		vk.vkDestroyRenderPass(self.device, self.renderPass, nil)
	end
	self.renderPass = nil

	if self.colorImageView then
		vk.vkDestroyImageView(self.device, self.colorImageView, nil)
	end
	self.colorImageView = nil
	if self.colorImageAndMemory then
		self.colorImageAndMemory:destroy()
	end
	self.colorImageAndMemory = nil
	
	if self.depthImageView then
		vk.vkDestroyImageView(self.device, self.depthImageView, nil)
	end
	if self.depthImageAndMemory then
		self.depthImageAndMemory:destroy()
	end
	self.depthImageAndMemory = nil
	
	self.obj:destroy()
end

return VulkanSwapchain
