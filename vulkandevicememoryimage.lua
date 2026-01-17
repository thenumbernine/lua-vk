-- helper class, not wrapper class
local ffi = require 'ffi'
local class = require 'ext.class'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor
local VKImage = require 'vk.image'
local VKMemory = require 'vk.memory'
local VulkanDeviceMemoryFromStagingBuffer = require 'vk.vulkandevicememoryfromstagingbuffer'


local VkMemoryRequirements = ffi.typeof'VkMemoryRequirements'



local VulkanDeviceMemoryImage = class()

function VulkanDeviceMemoryImage:createImage(
	physDev,
	device,
	width,
	height,
	mipLevels,
	numSamples,
	format,
	tiling,
	usage,
	properties
)
	local image = VKImage{
		device = device,
		imageType = vk.VK_IMAGE_TYPE_2D,
		format = format,
		extent = {
			width = width,
			height = height,
			depth = 1,
		},
		mipLevels = mipLevels,
		arrayLayers = 1,
		samples = numSamples,
		tiling = tiling,
		usage = usage,
		sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
		initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED,
	}

	local memReq = vkGet(
		VkMemoryRequirements,
		nil,
		vk.vkGetImageMemoryRequirements,
		device,
		image.id
	)
	local imageMemory = VKMemory{
		device = device,
		allocationSize = memReq.size,
		memoryTypeIndex = physDev:findMemoryType(memReq.memoryTypeBits, properties),
	}
	image:bindMemory(imageMemory.id)

	return setmetatable({
		device = device,
		image = image,
		imageMemory = imageMemory,
	}, VulkanDeviceMemoryImage)
end

function VulkanDeviceMemoryImage:makeTextureFromStaged(
	physDev,
	device,
	commandPool,
	srcData,
	bufferSize,
	texWidth,
	texHeight,
	mipLevels
)
	local stagingBufferAndMemory = VulkanDeviceMemoryFromStagingBuffer:create(
		physDev,
		device,
		srcData,
		bufferSize
	)

	local imageAndMemory = self:createImage(
		physDev,
		device,
		texWidth,
		texHeight,
		mipLevels,
		vk.VK_SAMPLE_COUNT_1_BIT,
		vk.VK_FORMAT_R8G8B8A8_SRGB,
		vk.VK_IMAGE_TILING_OPTIMAL,
		bit.bor(
			vk.VK_IMAGE_USAGE_TRANSFER_SRC_BIT,
			vk.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
			vk.VK_IMAGE_USAGE_SAMPLED_BIT
		),
		vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
	)

	commandPool:transitionImageLayout(
		imageAndMemory.image.id,
		vk.VK_IMAGE_LAYOUT_UNDEFINED,
		vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
		mipLevels
	)

	commandPool:copyBufferToImage(
		stagingBufferAndMemory.buffer,
		imageAndMemory.image.id,
		texWidth,
		texHeight
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

return VulkanDeviceMemoryImage
