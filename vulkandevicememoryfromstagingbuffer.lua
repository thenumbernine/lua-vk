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

	self.memReq = vkGet(VkMemoryRequirements, nil, vk.vkGetBufferMemoryRequirements, device, buffer.id)

	self.info = VkMemoryAllocateInfo()
	self.info.sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO
	self.info.allocationSize = self.memReq.size
	self.info.memoryTypeIndex = physDev:findMemoryType(
		self.memReq.memoryTypeBits,
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
		self.info,
		nil
	)
	self.info = nil
	self.memReq = nil

	vkassert(vk.vkBindBufferMemory, device, buffer.id, memory, 0)

	self.dstData = vkGet(void_ptr, vkassert, vk.vkMapMemory, device, memory, 0, bufferSize, 0)
	ffi.copy(self.dstData, srcData, bufferSize)
	self.dstData = nil

	vk.vkUnmapMemory(device, memory)

	return {
		buffer = buffer,
		memory = memory,
	}
end

return VulkanDeviceMemoryFromStagingBuffer
