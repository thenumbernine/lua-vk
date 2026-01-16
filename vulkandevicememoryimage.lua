-- helper class, not wrapper class
local ffi = require 'ffi'
local class = require 'ext.class'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor
local VulkanDeviceMemoryFromStagingBuffer = require 'vk.vulkandevicememoryfromstagingbuffer'


local VkDeviceMemory = ffi.typeof'VkDeviceMemory'
local VkImage = ffi.typeof'VkImage'
local VkMemoryRequirements = ffi.typeof'VkMemoryRequirements'


local makeVkImageCreateInfo = makeStructCtor'VkImageCreateInfo'
local makeVkMemoryAllocateInfo = makeStructCtor'VkMemoryAllocateInfo'

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
	local image = vkGet(
		VkImage,
		vkassert,
		vk.vkCreateImage,
		device,
		makeVkImageCreateInfo{
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
		},
		nil
	)

	local memReq = vkGet(
		VkMemoryRequirements,
		nil,
		vk.vkGetImageMemoryRequirements,
		device,
		image
	)

	local imageMemory = vkGet(
		VkDeviceMemory,
		vkassert,
		vk.vkAllocateMemory,
		device,
		makeVkMemoryAllocateInfo{
			allocationSize = memReq.size,
			memoryTypeIndex = physDev:findMemoryType(memReq.memoryTypeBits, properties),
		},
		nil
	)

	vkassert(vk.vkBindImageMemory, device, image, imageMemory, 0)

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
		imageAndMemory.image,
		vk.VK_IMAGE_LAYOUT_UNDEFINED,
		vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
		mipLevels
	)

	commandPool:copyBufferToImage(
		stagingBufferAndMemory.buffer,
		imageAndMemory.image,
		texWidth,
		texHeight
	)

	vk.vkFreeMemory(device, stagingBufferAndMemory.memory, nil)
	stagingBufferAndMemory.buffer:destroy()

	return imageAndMemory
end

function VulkanDeviceMemoryImage:destroy()
	if self.imageMemory then
		vk.vkFreeMemory(self.device, self.imageMemory, nil)
	end
	if self.image then
		vk.vkDestroyImage(self.device, self.image, nil)
	end
	self.imageMemory = nil
	self.image = nil
end

return VulkanDeviceMemoryImage
