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
	local info = ffi.new(VkImageCreateInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO
	info[0].imageType = vk.VK_IMAGE_TYPE_2D
	info[0].format = format
	info[0].extent.width = width
	info[0].extent.height = height
	info[0].extent.depth = 1
	info[0].mipLevels = mipLevels
	info[0].arrayLayers = 1
	info[0].samples = numSamples
	info[0].tiling = tiling
	info[0].usage = usage
	info[0].sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE
	info[0].initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED
	local image = vkGet(VkImage, vkassert, vk.vkCreateImage, device, info, nil)

	local memReq = vkGet(VkMemoryRequirements, nil, vk.vkGetImageMemoryRequirements, device, image)

	local info = ffi.new(VkMemoryAllocateInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO
	info[0].allocationSize = memReq.size
	info[0].memoryTypeIndex = physDev:findMemoryType(memReq.memoryTypeBits, properties)
	local imageMemory = vkGet(VkDeviceMemory, vkassert, vk.vkAllocateMemory, device, info, nil)
	vkassert(vk.vkBindImageMemory, device, image, imageMemory, 0)

	return {image=image, imageMemory=imageMemory}
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
