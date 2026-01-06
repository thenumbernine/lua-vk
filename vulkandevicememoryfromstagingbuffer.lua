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
local VkMemoryAllocateInfo_1 = ffi.typeof'VkMemoryAllocateInfo[1]'


local VulkanDeviceMemoryFromStagingBuffer = class()

function VulkanDeviceMemoryFromStagingBuffer:create(physDev, device, srcData, bufferSize)
	local buffer = VKBuffer{
		device = device,
		size = bufferSize,
		usage = vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
		sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
	}

	local memReq = vkGet(
		VkMemoryRequirements,
		nil,
		vk.vkGetBufferMemoryRequirements,
		device,
		buffer.id
	)

	local memory = vkGet(
		VkDeviceMemory,
		vkassert,
		vk.vkAllocateMemory,
		device,
		ffi.new(VkMemoryAllocateInfo_1, {{
			allocationSize = memReq.size,
			memoryTypeIndex = physDev:findMemoryType(
				memReq.memoryTypeBits,
				bit.bor(
					vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
					vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
				)
			),
		}}),
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
