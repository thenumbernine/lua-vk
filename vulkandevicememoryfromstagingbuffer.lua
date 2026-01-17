-- helper class, not wrapper class
local ffi = require 'ffi'
local class = require 'ext.class'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local VKBuffer = require 'vk.buffer'
local VKMemory = require 'vk.memory'


local void_ptr = ffi.typeof'void*'


local VulkanDeviceMemoryFromStagingBuffer = class()

function VulkanDeviceMemoryFromStagingBuffer:create(physDev, device, srcData, bufferSize)
	local buffer = VKBuffer{
		device = device,
		size = bufferSize,
		usage = vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
		sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
	}

	local memReq = buffer:getMemReq()
	local memory = VKMemory{
		device = device,
		allocationSize = memReq.size,
		memoryTypeIndex = physDev:findMemoryType(
			memReq.memoryTypeBits,
			bit.bor(
				vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
				vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
			)
		),
	}

	assert(buffer:bindMemory(memory.id))

	local dstData = vkGet(void_ptr, vkassert, vk.vkMapMemory, device, memory.id, 0, bufferSize, 0)
	ffi.copy(dstData, srcData, bufferSize)

	vk.vkUnmapMemory(device, memory.id)

	return {
		buffer = buffer,
		memory = memory,
	}
end

return VulkanDeviceMemoryFromStagingBuffer
