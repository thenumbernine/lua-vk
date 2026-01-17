local ffi = require 'ffi'
local class = require 'ext.class'
local vk = require 'vk'
local VKBuffer = require 'vk.buffer'
local VKMemory = require 'vk.memory'


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

	local dstData = memory:map(bufferSize)
	ffi.copy(dstData, srcData, bufferSize)

	memory:unmap()

	return {
		buffer = buffer,
		memory = memory,
	}
end

return VulkanDeviceMemoryFromStagingBuffer
