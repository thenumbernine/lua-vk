require 'ext.gc'
local class = require 'ext.class'
local vk = require 'vk'
local VKBuffer = require 'vk.buffer'
local VKMemory = require 'vk.memory'


local VulkanDeviceMemoryBuffer = class()

function VulkanDeviceMemoryBuffer:init(args)
	local device = args.device

	self.device = device
	self.buffer = VKBuffer{
		device = device,
		size = args.size,
		usage = args.usage,
		-- memory fields:
		physDev = args.physDev,
		memProps = args.properties,
	}

	self.memory = self.buffer.memory
end

function VulkanDeviceMemoryBuffer:makeBufferFromStaged(args)
	local physDev = args.physDev
	local device = args.device
	local commandPool = args.commandPool
	local queue = args.queue
	local srcData = args.srcData
	local bufferSize = args.bufferSize
	local usage = args.usage

	-- TODO esp this, is a raii ,and should free upon dtor upon scope end
	local stagingBufferAndMemory = {
		buffer = VKBuffer{
			device = device,
			size = bufferSize,
			usage = vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
			-- memory fields:
			physDev = physDev,
			memProps = bit.bor(
				vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
				vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
			),
			data = srcData,
		},
	}
	stagingBufferAndMemory.memory = stagingBufferAndMemory.buffer.memory 

	local bufferAndMemory = VulkanDeviceMemoryBuffer{
		physDev = physDev,
		device = device,
		size = bufferSize,
		usage = usage,
		properties = vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
	}

	queue:copyBuffer(
		commandPool,
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
