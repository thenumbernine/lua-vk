local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkGet = require 'vk.util'.vkGet
local vkResult = require 'vk.util'.vkResult
local makeStructCtor = require 'vk.util'.makeStructCtor
local VKCommandBuffer = require 'vk.commandbuffer'


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

local makeVkPresentInfoKHR = makeStructCtor(
	'VkPresentInfoKHR',
	{
		{
			name = 'swapchains',
			type = 'VkSwapchainKHR',
			gen = function(x)
				if x.obj then x = x.obj end
				if x.id then x = x.id end
				return x
			end,
		},
		{
			name = 'waitSemaphores',
			type = 'VkSemaphore',
		},
	}
)



local VKQueue = class()

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

VKQueue.makeVkSubmitInfo = makeVkSubmitInfo 
function VKQueue:submit(submitInfo, numInfo, fences)
	return vkResult(vk.vkQueueSubmit(
		self.id,
		numInfo or 1,
		submitInfo,
		fences
	), 'vkQueueSubmit')
end

function VKQueue:waitIdle()
	return vkResult(vk.vkQueueWaitIdle(self.id), 'vkQueueWaitIdle')
end

VKQueue.makeVkPresentInfoKHR = makeVkPresentInfoKHR 
function VKQueue:present(presentInfo)
	return vkResult(vk.vkQueuePresentKHR(self.id, presentInfo))
end

-- extra functionality
function VKQueue:singleTimeCommand(commandPool, callback)
	local cmds = commandPool:makeCmds{
		level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
	}

	assert(cmds:begin{
		flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
	})

	callback(cmds)

	assert(cmds:done())

	assert(self:submit(
		makeVkSubmitInfo{
			-- don't use conversion field, just use the pointer
			commandBufferCount = 1,
			pCommandBuffers = cmds.idptr,
		}
	))

	assert(self:waitIdle())
	cmds:destroy()
end

return VKQueue
