-- helper class, not wrapper class
local ffi = require 'ffi'
local class = require 'ext.class'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local VKBuffer = require 'vk.buffer'


local void_ptr = ffi.typeof'void*'
local VkDeviceMemory = ffi.typeof'VkDeviceMemory'
local VkMemoryRequirements = ffi.typeof'VkMemoryRequirements'
local VkMemoryAllocateInfo = ffi.typeof'VkMemoryAllocateInfo'


local VulkanDeviceMemoryFromStagingBuffer = class()

function VulkanDeviceMemoryFromStagingBuffer:create(physDev, device, srcData, bufferSize)
	local buffer = VKBuffer{
		device = device,
		size = bufferSize,
		usage = vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
		sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
	}

	local memReq = vkGet(VkMemoryRequirements, nil, vk.vkGetBufferMemoryRequirements, device, buffer.id)

	local info = VkMemoryAllocateInfo()
	info.sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO
	info.allocationSize = memReq.size
	info.memoryTypeIndex = physDev:findMemoryType(
		memReq.memoryTypeBits,
		bit.bor(
			vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
			vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
		)
	)
	local memory = vkGet(
		VkDeviceMemory,
		vkassert,
		vk.vkAllocateMemory,
		device,
		info,
		nil
	)

	vkassert(vk.vkBindBufferMemory, device, buffer.id, memory, 0)

	local dstData = vkGet(void_ptr, vkassert, vk.vkMapMemory, device, memory, 0, bufferSize, 0)
	ffi.copy(dstData, srcData, bufferSize)

	vk.vkUnmapMemory(device, memory)

	return {
		buffer = buffer,
		memory = memory,
	}
end

return VulkanDeviceMemoryFromStagingBuffer
