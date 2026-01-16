local ffi = require 'ffi'
local class = require 'ext.class'
local assertindex = require 'ext.assert'.index
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor
local VKDevice = require 'vk.device'


local VkCommandBuffer_1 = ffi.typeof'VkCommandBuffer[1]'
local VkQueue = ffi.typeof'VkQueue'

local makeVkCommandBufferAllocateInfo = makeStructCtor'VkCommandBufferAllocateInfo'
local makeVkCommandBufferBeginInfo = makeStructCtor'VkCommandBufferBeginInfo'

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
	local device = assertindex(args, 'device')
	if VKDevice:isa(device) then device = device.id end
	
	local queueFamilyIndex = assertindex(args, 'family')
	local queueIndex = args.index or 0

	-- queues don't get gc'd so ...
	self.id = vkGet(VkQueue, nil, vk.vkGetDeviceQueue, device, queueFamilyIndex, queueIndex)
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

function VKQueue:singleTimeCommand(device, commandPool, callback)
	--[[
	local vkGet = require 'vk.util'.vkGet
	local VkCommandBuffer = ffi.typeof'VkCommandBuffer'
	local cmds = vkGet(
		VkCommandBuffer,
		vkassert,
		vk.vkAllocateCommandBuffers,
		device,
		makeVkCommandBufferAllocateInfo{
			commandPool = commandPool,
			level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
			commandBufferCount = 1,
		}
	)
	--]]
	-- [[ I want to keep the pointer so ...
	local cmds = VkCommandBuffer_1()
	vkassert(
		vk.vkAllocateCommandBuffers,
		device,
		makeVkCommandBufferAllocateInfo{
			commandPool = commandPool,
			level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
			commandBufferCount = 1,
		},
		cmds
	)
	--]]

	vkassert(
		vk.vkBeginCommandBuffer,
		cmds[0],
		makeVkCommandBufferBeginInfo{
			flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
		}
	)

	callback(cmds[0])

	vkassert(vk.vkEndCommandBuffer, cmds[0])

	self:submit(
		makeVkSubmitInfo{
			-- don't use conversion field, just use the pointer
			commandBufferCount = 1,
			pCommandBuffers = cmds,
		}
	)

	vkassert(vk.vkQueueWaitIdle, self.id)

	vk.vkFreeCommandBuffers(device, commandPool, 1, cmds)
end



return VKQueue
