require 'ext.gc'
local class = require 'ext.class'
local vk = require 'vk'
local VKBuffer = require 'vk.buffer'


local VulkanDeviceMemoryBuffer = class()

function VulkanDeviceMemoryBuffer:makeBufferFromStaged(args)
	local stagingBufferAndMemory = VKBuffer{
		device = args.device,
		size = args.bufferSize,
		usage = vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
		-- memory fields:
		physDev = args.physDev,
		memProps = bit.bor(
			vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
			vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
		),
		data = args.srcData,
	}

	local bufferAndMemory = VKBuffer{
		device = args.device,
		size = args.bufferSize,
		usage = args.usage,
		physDev = args.physDev,
		memProps = vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
	}

	args.queue:copyBuffer(
		args.commandPool,
		stagingBufferAndMemory,
		bufferAndMemory,
		args.bufferSize
	)

	stagingBufferAndMemory:destroy()

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
