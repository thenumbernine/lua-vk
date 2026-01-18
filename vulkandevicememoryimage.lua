require 'ext.gc'
local class = require 'ext.class'
local vk = require 'vk'
local VKImage = require 'vk.image'
local VKMemory = require 'vk.memory'
local VulkanDeviceMemoryFromStagingBuffer = require 'vk.vulkandevicememoryfromstagingbuffer'


local VulkanDeviceMemoryImage = class()

function VulkanDeviceMemoryImage:makeImage(args)
	local image = VKImage{
		device = args.device,
		imageType = vk.VK_IMAGE_TYPE_2D,
		format = args.format,
		extent = {
			width = args.width,
			height = args.height,
			depth = 1,
		},
		mipLevels = args.mipLevels,
		arrayLayers = 1,
		samples = args.samples,
		tiling = args.tiling,
		usage = args.usage,
		sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
		initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED,
	}

	local memReq = image:getMemReq()
	local imageMemory = VKMemory{
		device = args.device,
		allocationSize = memReq.size,
		memoryTypeIndex = args.physDev:findMemoryType(
			memReq.memoryTypeBits,
			args.properties
		),
	}
	assert(image:bindMemory(imageMemory.id))

	return setmetatable({
		device = args.device,
		image = image,
		imageMemory = imageMemory,
	}, VulkanDeviceMemoryImage)
end

function VulkanDeviceMemoryImage:makeImageAndView(args)
	local image = self:makeImage(args)
	local imageView = image.image:makeImageView{
		viewType = vk.VK_IMAGE_VIEW_TYPE_2D,
		format = args.format,
		subresourceRange = {
			aspectMask = args.aspectMask,
			levelCount = args.mipLevels or 1,
			layerCount = args.layerCount or 1,
		},
	}
	return image, imageView
end

function VulkanDeviceMemoryImage:makeTextureFromStaged(args)
	local stagingBufferAndMemory = VulkanDeviceMemoryFromStagingBuffer:create(
		args.physDev,
		args.device,
		args.srcBuffer,
		args.bufferSize
	)

	local imageAndMemory = self:makeImage{
		physDev = args.physDev,
		device = args.device,
		width = args.width,
		height = args.height,
		mipLevels = args.mipLevels,
		samples = vk.VK_SAMPLE_COUNT_1_BIT,
		format = vk.VK_FORMAT_R8G8B8A8_SRGB,
		tiling = vk.VK_IMAGE_TILING_OPTIMAL,
		usage = bit.bor(
			vk.VK_IMAGE_USAGE_TRANSFER_SRC_BIT,
			vk.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
			vk.VK_IMAGE_USAGE_SAMPLED_BIT
		),
		properties = vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
	}

	args.commandPool:transitionImageLayout(
		imageAndMemory.image.id,
		vk.VK_IMAGE_LAYOUT_UNDEFINED,
		vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
		args.mipLevels
	)

	args.commandPool:copyBufferToImage(
		stagingBufferAndMemory.buffer,
		imageAndMemory.image.id,
		args.width,
		args.height
	)

	stagingBufferAndMemory.memory:destroy()
	stagingBufferAndMemory.buffer:destroy()

	return imageAndMemory
end

function VulkanDeviceMemoryImage:destroy()
	if self.imageMemory then
		self.imageMemory:destroy()
	end
	self.imageMemory = nil

	if self.image then
		self.image:destroy()
	end
	self.image = nil
end

function VulkanDeviceMemoryImage:__gc()
	return self:destroy()
end

return VulkanDeviceMemoryImage
