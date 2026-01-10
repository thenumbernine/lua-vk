-- helper class, not wrapper class
local ffi = require 'ffi'
local class = require 'ext.class'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local VKBuffer = require 'vk.buffer'
local VulkanDeviceMemoryFromStagingBuffer = require 'vk.vulkandevicememoryfromstagingbuffer'


local VkDeviceMemory = ffi.typeof'VkDeviceMemory'
local VkMemoryRequirements = ffi.typeof'VkMemoryRequirements'
local VkMemoryAllocateInfo_1 = ffi.typeof'VkMemoryAllocateInfo[1]'


local VulkanDeviceMemoryBuffer = class()

function VulkanDeviceMemoryBuffer:init(physDev, device, size, usage, properties)
	self.buffer = VKBuffer{
		device = device,
		size = size,
		usage = usage,
		sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
	}

	local memReq = vkGet(VkMemoryRequirements, nil, vk.vkGetBufferMemoryRequirements, device, self.buffer.id)

	self.info = VkMemoryAllocateInfo_1()
	self.info[0].allocationSize = memReq.size
	self.info[0].memoryTypeIndex = physDev:findMemoryType(memReq.memoryTypeBits, properties)
	self.memory = vkGet(VkDeviceMemory, vkassert, vk.vkAllocateMemory, device, self.info, nil)
	self.info = nil

	vkassert(vk.vkBindBufferMemory, device, self.buffer.id, self.memory, 0)
end

function VulkanDeviceMemoryBuffer:makeBufferFromStaged(physDev, device, commandPool, srcData, bufferSize)
	-- TODO esp this, is a raii ,and should free upon dtor upon scope end
	local stagingBufferAndMemory = VulkanDeviceMemoryFromStagingBuffer:create(
		physDev,
		device,
		srcData,
		bufferSize
	)

	local bufferAndMemory = VulkanDeviceMemoryBuffer(
		physDev,
		device,
		bufferSize,
		bit.bor(
			vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
			vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT
		),
		vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
	)

	commandPool:copyBuffer(
		stagingBufferAndMemory.buffer,
		bufferAndMemory.buffer,
		bufferSize
	)

	stagingBufferAndMemory.buffer:destroy()

	return bufferAndMemory
end

return VulkanDeviceMemoryBuffer
