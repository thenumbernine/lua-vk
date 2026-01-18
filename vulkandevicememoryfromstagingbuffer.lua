local ffi = require 'ffi'
local class = require 'ext.class'
local vk = require 'vk'
local VKBuffer = require 'vk.buffer'


local VulkanDeviceMemoryFromStagingBuffer = class()

function VulkanDeviceMemoryFromStagingBuffer:create(physDev, device, srcData, bufferSize)
	local buffer = VKBuffer{
		device = device,
		size = bufferSize,
		usage = vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
		-- memory fields:
		physDev = physDev,
		memProps = bit.bor(
			vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
			vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
		),
	}
	local memory = buffer.memory

	local dstData = memory:map(bufferSize)
	ffi.copy(dstData, srcData, bufferSize)
	memory:unmap()

	return {
		buffer = buffer,
		memory = memory,
	}
end

return VulkanDeviceMemoryFromStagingBuffer
