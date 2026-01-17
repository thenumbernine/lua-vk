-- helper not wrapper
local ffi = require 'ffi'
local class = require 'ext.class'
local table = require 'ext.table'
local range = require 'ext.range'
local asserteq = require 'ext.assert'.eq
local vk = require 'vk'
local countof = require 'vk.util'.countof
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor
local VulkanDeviceMemoryImage = require 'vk.vulkandevicememoryimage'
local VKSwapchain = require 'vk.swapchain'
local VKRenderPass = require 'vk.renderpass'
local VKFramebuffer = require 'vk.framebuffer'
local VKImageView = require 'vk.imageview'


local VkAttachmentReference = ffi.typeof'VkAttachmentReference'
local VkExtent2D = ffi.typeof'VkExtent2D'
local VkImageView_array = ffi.typeof'VkImageView[?]'
local VkRenderPass = ffi.typeof'VkRenderPass'



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
		queueFamilyIndices = familiesDiffer and indices,
	}

	self.images = self.obj:getImages()

	local numImageViews = #self.images
	self.imageViews = range(numImageViews):mapi(function(i)
		return self:createImageView(
			device,
			self.images.v[i-1],
			surfaceFormat.format,
			vk.VK_IMAGE_ASPECT_COLOR_BIT,
			1
		)
	end)

	local swapChainImageFormat = surfaceFormat.format
	self.renderPass = VKRenderPass{
		device = device,
		attachments = {
			{	-- colorAttachment
				format = swapChainImageFormat,
				samples = msaaSamples,
				loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR,
				storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE,
				stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
				stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE,
				initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED,
				finalLayout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
			},
			{	-- depthAttachment
				format = physDev:findDepthFormat(),
				samples = msaaSamples,
				loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR,
				storeOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE,
				stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
				stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE,
				initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED,
				finalLayout = vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
			},
			{	-- colorAttachmentResolve
				format = swapChainImageFormat,
				samples = vk.VK_SAMPLE_COUNT_1_BIT,
				loadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
				storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE,
				stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
				stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE,
				initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED,
				finalLayout = vk.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
			},
		},
		subpasses = {
			{
				pipelineBindPoint = vk.VK_PIPELINE_BIND_POINT_GRAPHICS,
				colorAttachments = {
					{
						attachment = 0,
						layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
					},
				},
				resolveAttachments = {
					{
						attachment = 2,
						layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
					},
				},
				depthStencilAttachment = {
					attachment = 1,
					layout = vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
				},
			},
		},
		dependencies = {
			{
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
			},
		},
	}


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
		self.colorImageAndMemory.image.id,
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
		self.depthImageAndMemory.image.id,
		depthFormat,
		vk.VK_IMAGE_ASPECT_DEPTH_BIT,
		1
	)

	self.framebuffers = table()
	for i=0,numImageViews-1 do
		local numAttachments = 3
		self.framebuffers:insert(
			VKFramebuffer{
				device = device,
				renderPass = self.renderPass.id,
				attachments = {
					self.colorImageView.id,
					self.depthImageView.id,
					self.imageViews[1+i].id,
				},
				width = width,
				height = height,
				layers = 1,
			}
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
	return VKImageView{
		device = device,
		image = image,
		viewType = vk.VK_IMAGE_VIEW_TYPE_2D,
		format = format,
		subresourceRange = {
			aspectMask = aspectFlags,
			levelCount = mipLevels,
			layerCount = 1,
		},
	}
end

function VulkanSwapchain:destroy()
	if self.framebuffers then
		for _,framebuffer in ipairs(self.framebuffers) do
			framebuffer:destroy()
		end
	end
	self.framebuffers = nil

	if self.imageViews then
		for _,imageView in ipairs(self.imageViews) do
			imageView:destroy()
		end
	end
	self.imageViews = nil

	self.images = nil

	if self.renderPass then
		self.renderPass:destroy()
	end
	self.renderPass = nil

	if self.colorImageView then
		self.colorImageView:destroy()
	end
	self.colorImageView = nil
	if self.colorImageAndMemory then
		self.colorImageAndMemory:destroy()
	end
	self.colorImageAndMemory = nil
	
	if self.depthImageView then
		self.depthImageView:destroy()
	end
	if self.depthImageAndMemory then
		self.depthImageAndMemory:destroy()
	end
	self.depthImageAndMemory = nil
	
	self.obj:destroy()
end

return VulkanSwapchain
