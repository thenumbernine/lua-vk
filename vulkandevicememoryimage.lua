-- helper class, not wrapper class
local ffi = require 'ffi'
local class = require 'ext.class'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local VulkanDeviceMemoryFromStagingBuffer = require 'vk.vulkandevicememoryfromstagingbuffer'


local VkDeviceMemory = ffi.typeof'VkDeviceMemory'
local VkImage = ffi.typeof'VkImage'
local VkImageCreateInfo_1 = ffi.typeof'VkImageCreateInfo[1]'
local VkMemoryAllocateInfo_1 = ffi.typeof'VkMemoryAllocateInfo[1]'
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
	self.info = VkImageCreateInfo_1()
	self.info[0].sType = vk.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO
	self.info[0].imageType = vk.VK_IMAGE_TYPE_2D
	self.info[0].format = format
	self.info[0].extent.width = width
	self.info[0].extent.height = height
	self.info[0].extent.depth = 1
	self.info[0].mipLevels = mipLevels
	self.info[0].arrayLayers = 1
	self.info[0].samples = numSamples
	self.info[0].tiling = tiling
	self.info[0].usage = usage
	self.info[0].sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE
	self.info[0].initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED
	local image = vkGet(VkImage, vkassert, vk.vkCreateImage, device, self.info, nil)
	self.info = nil

	self.memReq = vkGet(VkMemoryRequirements, nil, vk.vkGetImageMemoryRequirements, device, image)
	self.info = VkMemoryAllocateInfo_1()
	self.info[0].sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO
	self.info[0].allocationSize = self.memReq.size
	self.info[0].memoryTypeIndex = physDev:findMemoryType(self.memReq.memoryTypeBits, properties)
	local imageMemory = vkGet(
		VkDeviceMemory,
		vkassert,
		vk.vkAllocateMemory,
		device,
		self.info,
		nil
	)
	self.info = nil
	self.memReq = nil

	vkassert(vk.vkBindImageMemory, device, image, imageMemory, 0)

	return {
		image = image,
		imageMemory = imageMemory,
	}
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
		bit.bor(vk.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
			vk.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
			vk.VK_IMAGE_USAGE_SAMPLED_BIT),
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

	stagingBufferAndMemory.buffer:destroy()

	return imageAndMemory
end

return VulkanDeviceMemoryImage
