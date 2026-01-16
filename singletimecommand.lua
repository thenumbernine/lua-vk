-- helper
local ffi = require 'ffi'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert

local VkCommandBufferAllocateInfo = ffi.typeof'VkCommandBufferAllocateInfo'
local VkCommandBuffer_1 = ffi.typeof'VkCommandBuffer[1]'
local VkCommandBufferBeginInfo = ffi.typeof'VkCommandBufferBeginInfo'
local VkSubmitInfo = ffi.typeof'VkSubmitInfo'


local self = {}	-- cuz i guess I need an object and I'm too lazy to rename it to a scope var name
local function VKSingleTimeCommand(device, queue, commandPool, callback)
	local info = VkCommandBufferAllocateInfo()
	info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
	info.commandPool = commandPool
	info.level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY
	info.commandBufferCount = 1
	--[[
	local vkGet = require 'vk.util'.vkGet
	local VkCommandBuffer = ffi.typeof'VkCommandBuffer'
	local cmds = vkGet(VkCommandBuffer, vkassert, vk.vkAllocateCommandBuffers, device, info)
	--]]
	-- [[ I want to keep the pointer so ...
	local cmds = VkCommandBuffer_1()
	vkassert(vk.vkAllocateCommandBuffers, device, info, cmds)
	--]]

	local info = VkCommandBufferBeginInfo()
	info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
	info.flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT
	vkassert(vk.vkBeginCommandBuffer, cmds[0], info)

	callback(cmds[0])

	vkassert(vk.vkEndCommandBuffer, cmds[0])

	local info = VkSubmitInfo()
	info.sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO
	info.commandBufferCount = 1
	info.pCommandBuffers = cmds
	vkassert(vk.vkQueueSubmit, queue, 1, info, nil)

	vkassert(vk.vkQueueWaitIdle, queue)

	vk.vkFreeCommandBuffers(device, commandPool, 1, cmds)
end

return VKSingleTimeCommand
