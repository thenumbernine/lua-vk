require 'ext.gc'
local class = require 'ext.class'
local vk = require 'vk'
local VKBuffer = require 'vk.buffer'
local VKMemory = require 'vk.memory'
local VulkanDeviceMemoryFromStagingBuffer = require 'vk.vulkandevicememoryfromstagingbuffer'


local VulkanDeviceMemoryBuffer = class()

function VulkanDeviceMemoryBuffer:init(physDev, device, size, usage, properties)
	self.device = device
	self.buffer = VKBuffer{
		device = device,
		size = size,
		usage = usage,
		sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
	}

	local memReq = self.buffer:getMemReq()
	self.memory = VKMemory{
		device = device,
		allocationSize = memReq.size,
		memoryTypeIndex = physDev:findMemoryType(
			memReq.memoryTypeBits,
			properties
		),
	}

	assert(self.buffer:bindMemory(self.memory.id))
end

function VulkanDeviceMemoryBuffer:makeBufferFromStaged(physDev, device, commandPool, srcData, bufferSize, usage)
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
		usage,
		vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
	)

	commandPool:copyBuffer(
		stagingBufferAndMemory.buffer,
		bufferAndMemory.buffer,
		bufferSize
	)

	stagingBufferAndMemory.memory:destroy()
	stagingBufferAndMemory.buffer:destroy()

	return bufferAndMemory
end

function VulkanDeviceMemoryBuffer:destroy()
	if self.memory then
		self.memory:destroy()
	end
	self.memory = nil

	if self.buffer then
		self.buffer:destroy()
	end
	self.buffer = nil
end

function VulkanDeviceMemoryBuffer:__gc()
	return self:destroy()
end

return VulkanDeviceMemoryBuffer
