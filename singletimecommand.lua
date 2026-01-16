-- helper
local ffi = require 'ffi'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local makeStructCtor = require 'vk.util'.makeStructCtor
require 'ffi.req' 'c.stdlib'	-- alloca

local VkCommandBuffer_1 = ffi.typeof'VkCommandBuffer[1]'


local makeVkCommandBufferAllocateInfo = makeStructCtor'VkCommandBufferAllocateInfo'
local makeVkCommandBufferBeginInfo = makeStructCtor'VkCommandBufferBeginInfo'
local makeVkSubmitInfo = makeStructCtor'VkSubmitInfo'


local self = {}	-- cuz i guess I need an object and I'm too lazy to rename it to a scope var name
local function VKSingleTimeCommand(device, queue, commandPool, callback)
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

	vkassert(
		vk.vkQueueSubmit,
		queue,
		1,
		makeVkSubmitInfo{
			commandBufferCount = 1,
			pCommandBuffers = cmds,
		},
		nil
	)

	vkassert(vk.vkQueueWaitIdle, queue)

	vk.vkFreeCommandBuffers(device, commandPool, 1, cmds)
end

return VKSingleTimeCommand
