local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor
local VKCommandBuffer = require 'vk.commandbuffer'


local VkCommandBuffer_1 = ffi.typeof'VkCommandBuffer[1]'
local VkQueue = ffi.typeof'VkQueue'

local makeVkSubmitInfo = makeStructCtor(
	'VkSubmitInfo',
	{
		{
			name = 'waitDstStageMask',
			ptrname = 'pWaitDstStageMask',
			type = 'VkPipelineStageFlags[1]',
			notarray = true,
		},
		{
			name = 'commandBuffers',
			type = 'VkCommandBuffer',
		},
	}
)



local VKQueue = class()

VKQueue.makeVkSubmitInfo = makeVkSubmitInfo 

function VKQueue:init(args)
	local device = assert.index(args, 'device')
	local VKDevice = require 'vk.device'
	if VKDevice:isa(device) then device = device.id end

	local queueFamilyIndex = assert.index(args, 'family')
	local queueIndex = args.index or 0

	self.id, self.idptr = vkGet(
		VkQueue,
		nil,
		vk.vkGetDeviceQueue,
		device,
		queueFamilyIndex,
		queueIndex
	)
end

function VKQueue:submit(submitInfo, numInfo, fences)
	vkassert(
		vk.vkQueueSubmit,
		self.id,
		numInfo or 1,
		submitInfo,
		fences
	)
end

function VKQueue:singleTimeCommand(commandPool, callback)
	local cmds = commandPool:makeCmds{
		level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
	}

	cmds:begin{
		flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
	}

	callback(cmds.id)

	vkassert(vk.vkEndCommandBuffer, cmds.id)

	self:submit(
		makeVkSubmitInfo{
			-- don't use conversion field, just use the pointer
			commandBufferCount = 1,
			pCommandBuffers = cmds.idptr,
		}
	)

	vkassert(vk.vkQueueWaitIdle, self.id)
	
	cmds:destroy()
end

return VKQueue
