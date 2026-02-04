require 'ext.gc'
local ffi = require 'ffi'
local math = require 'ext.math'	-- clamp
local class = require 'ext.class'
local table = require 'ext.table'
local assert = require 'ext.assert'
local vk = require 'vk'


local VkExtent2D = ffi.typeof'VkExtent2D'


local VulkanSwapchain = class()

function VulkanSwapchain:init(args)
	local width = args.width
	local height = args.height
	local physDev = args.physDev
	local device = args.device
	local surface = args.surface
	local msaaSamples = args.msaaSamples

	local swapChainSupport = physDev:querySwapChainSupport(surface)

	-- same as device.  superclass?
	self.autodestroys = table()

	if swapChainSupport.capabilities.currentExtent.width ~= 0xFFFFFFFF then
		self.extent = VkExtent2D(swapChainSupport.capabilities.currentExtent)
	else
		local actualExtent = VkExtent2D(width, height)
		actualExtent.width = math.clamp(actualExtent.width, swapChainSupport.capabilities.minImageExtent.width, swapChainSupport.capabilities.maxImageExtent.width)
		actualExtent.height = math.clamp(actualExtent.height, swapChainSupport.capabilities.minImageExtent.height, swapChainSupport.capabilities.maxImageExtent.height)
		self.extent = actualExtent
	end

	local imageCount = swapChainSupport.capabilities.minImageCount + 1
	if swapChainSupport.capabilities.maxImageCount > 0 then
		imageCount = math.min(imageCount, swapChainSupport.capabilities.maxImageCount)
	end

	local surfaceFormat = select(2, swapChainSupport.formats:totable():find(nil, function(format)
		return format.format == vk.VK_FORMAT_B8G8R8A8_SRGB
		and format.colorSpace == vk.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR
	end)) or swapChainSupport.formats:begin()

	local indices = physDev:findQueueFamilies(surface)
	indices = table.keys{
		[indices.graphicsFamily] = true,
		[indices.presentFamily] = true,
	}

	local familiesDiffer = (indices.graphicsFamily ~= indices.presentFamily) or nil
	self.obj = device:makeSwapchain{
		surface = surface.id,
		minImageCount = imageCount,
		imageFormat = surfaceFormat.format,
		imageColorSpace = surfaceFormat.colorSpace,
		imageExtent = self.extent,
		imageArrayLayers = 1,
		imageUsage = vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
		preTransform = swapChainSupport.capabilities.currentTransform,
		compositeAlpha = vk.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
		presentMode = select(2, swapChainSupport.presentModes:totable():find(nil, function(presentMode)
				return presentMode == vk.VK_PRESENT_MODE_MAILBOX_KHR
			end)) or vk.VK_PRESENT_MODE_FIFO_KHR,
		clipped = vk.VK_TRUE,
		imageSharingMode = familiesDiffer and vk.VK_SHARING_MODE_CONCURRENT or vk.VK_SHARING_MODE_EXCLUSIVE,
		queueFamilyIndices = familiesDiffer and indices,
	}
	assert.eq(self.obj, device.autodestroys:remove())
	self.autodestroys:insert(self.obj)

	self.imageViews = self.obj:getImages():mapi(function(image, i)
		local imageView = image:makeView{
			viewType = vk.VK_IMAGE_VIEW_TYPE_2D,
			format = surfaceFormat.format,
			subresourceRange = {
				aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
				levelCount = 1,
				layerCount = 1,
			},
		}
		assert.eq(imageView, device.autodestroys:remove())
		self.autodestroys:insert(imageView)
		return imageView
	end)

	local swapChainImageFormat = surfaceFormat.format
	self.renderPass = device:makeRenderPass{
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
	assert.eq(self.renderPass, device.autodestroys:remove())
	self.autodestroys:insert(self.renderPass)

	self.colorImage = device:makeImage{
		format = surfaceFormat.format,
		extent = {
			width = width,
			height = height,
		},
		samples = msaaSamples,
		usage = bit.bor(
			vk.VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT,
			vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT
		),
		-- TODO should sharing mode match swapchain sharing mode, which changes when families differ?
		--sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
		-- VKMemory:
		physDev = physDev,
		memProps = vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
		-- VkImageView:
		aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
	}
	assert.eq(self.colorImage, device.autodestroys:remove())
	self.autodestroys:insert(self.colorImage)

	self.depthImage = device:makeImage{
		format = physDev:findDepthFormat(),
		extent = {
			width = width,
			height = height,
		},
		samples = msaaSamples,
		usage = vk.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
		-- VKMemory:
		physDev = physDev,
		memProps = vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
		-- VkImageView:
		aspectMask = vk.VK_IMAGE_ASPECT_DEPTH_BIT,
	}
	assert.eq(self.depthImage, device.autodestroys:remove())
	self.autodestroys:insert(self.depthImage)

	self.framebuffers = self.imageViews:mapi(function(imageView)
		local framebuffer = device:makeFramebuffer{
			renderPass = self.renderPass.id,
			attachments = {
				self.colorImage.view.id,
				self.depthImage.view.id,
				imageView.id,
			},
			width = width,
			height = height,
			layers = 1,
		}
		assert.eq(framebuffer, device.autodestroys:remove())
		self.autodestroys:insert(framebuffer)
		return framebuffer
	end)
end

function VulkanSwapchain:destroy()
	if self.autodestroys then
		--for i=1,#self.autodestroys do
		for i=#self.autodestroys,1,-1 do
			self.autodestroys[i]:destroy()
		end
		self.autodestroys = nil
	end
end

function VulkanSwapchain:__gc()
	return self:destroy()
end

return VulkanSwapchain
