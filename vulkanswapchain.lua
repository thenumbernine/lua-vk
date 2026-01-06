-- helper not wrapper
local ffi = require 'ffi'
local class = require 'ext.class'
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
local VkSubpassDescription = ffi.typeof'VkSubpassDescription'
local VkSubpassDependency = ffi.typeof'VkSubpassDependency'
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

	self.imageViews = vector(VkImageView)
	for i=0,#self.images-1 do
		self.imageViews:emplace_back()[0] = self:createImageView(
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

	self.framebuffers = vector(VkFramebuffer)
	for i=0,#self.imageViews-1 do
		self.attachments = vector(VkImageView, {
			self.colorImageView,
			self.depthImageView,
			self.imageViews.v[i],
		})
		self.info = ffi.new(VkFramebufferCreateInfo_1, {{
			sType = vk.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
			renderPass = self.renderPass,
			attachmentCount = #self.attachments,
			pAttachments = self.attachments.v,
			width = width,
			height = height,
			layers = 1,
		}})
		self.framebuffers:push_back(vkGet(
			VkFramebuffer,
			vkassert,
			vk.vkCreateFramebuffer,
			device.id,
			self.info,
			nil
		))
		self.info = nil
		self.attachments = nil
	end
end

function VulkanSwapchain:chooseSwapExtent(width, height, capabilities)
	if capabilities.currentExtent.width ~= -1 then
		return ffi.new(VkExtent2D, capabilities.currentExtent)
	else
		local actualExtent = ffi.new(VkExtent2D, width, height)
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
	self.info = ffi.new(VkImageViewCreateInfo_1, {{
		sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
		image = image,
		viewType = vk.VK_IMAGE_VIEW_TYPE_2D,
		format = format,
		subresourceRange = {
			aspectMask = aspectFlags,
			levelCount = mipLevels,
			layerCount = 1,
		},
	}})
	local result = vkGet(VkImageView, vkassert, vk.vkCreateImageView, device, self.info, nil)
	self.info = nil
	return result
end

function VulkanSwapchain:createRenderPass(physDev, device, swapChainImageFormat, msaaSamples)
	-- need to keep these from gc'ing until the function is through ...
	self.attachments = vector(VkAttachmentDescription, {
		{-- colorAttachment
			format = swapChainImageFormat,
			samples = msaaSamples,
			loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR,
			storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE,
			stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
			stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE,
			initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED,
			finalLayout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
		},
		{-- depthAttachment
			format = physDev:findDepthFormat(),
			samples = msaaSamples,
			loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR,
			storeOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE,
			stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
			stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE,
			initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED,
			finalLayout = vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
		},
		{-- colorAttachmentResolve
			format = swapChainImageFormat,
			samples = vk.VK_SAMPLE_COUNT_1_BIT,
			loadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
			storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE,
			stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
			stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE,
			initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED,
			finalLayout = vk.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
		},
	})

	self.colorAttachmentRef = ffi.new(VkAttachmentReference_1, {{
		attachment = 0,
		layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
	}})
	self.depthAttachmentRef = ffi.new(VkAttachmentReference_1, {{
		attachment = 1,
		layout = vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
	}})
	self.colorAttachmentResolveRef = ffi.new(VkAttachmentReference_1, {{
		attachment = 2,
		layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
	}})

	self.subpasses = vector(VkSubpassDescription, {{
		pipelineBindPoint = vk.VK_PIPELINE_BIND_POINT_GRAPHICS,
		colorAttachmentCount = 1,
		pColorAttachments = self.colorAttachmentRef,
		pResolveAttachments = self.colorAttachmentResolveRef,
		pDepthStencilAttachment = self.depthAttachmentRef,
	}})

	self.dependencies = vector(VkSubpassDependency, {{
		srcSubpass = vk.VK_SUBPASS_EXTERNAL,
		dstSubpass = 0,
		srcStageMask = bit.bor(
			vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
			vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT
		),
		dstStageMask = bit.bor(
			vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
			vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT
		),
		srcAccessMask = 0,
		dstAccessMask = bit.bor(
			vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
			vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT
		),
	}})

	self.info = ffi.new(VkRenderPassCreateInfo_1, {{
		sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
		attachmentCount = #self.attachments,
		pAttachments = self.attachments.v,
		subpassCount = #self.subpasses,
		pSubpasses = self.subpasses.v,
		dependencyCount = #self.dependencies,
		pDependencies = self.dependencies.v,
	}})

	local result = vkGet(VkRenderPass, vkassert, vk.vkCreateRenderPass, device, self.info, nil)

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
