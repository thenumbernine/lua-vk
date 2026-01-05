-- helper
local ffi = require 'ffi'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert

local VkCommandBufferAllocateInfo_1 = ffi.typeof'VkCommandBufferAllocateInfo[1]'
local VkCommandBuffer_1 = ffi.typeof'VkCommandBuffer[1]'
local VkCommandBufferBeginInfo_1 = ffi.typeof'VkCommandBufferBeginInfo[1]'
local VkSubmitInfo_1 = ffi.typeof'VkSubmitInfo[1]'


local function VKSingleTimeCommand(device, queue, commandPool, callback)
	local info = ffi.new(VkCommandBufferAllocateInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
	info[0].commandPool = commandPool
	info[0].level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY
	info[0].commandBufferCount = 1
	--[[
	local vkGet = require 'vk.util'.vkGet
	local VkCommandBuffer = ffi.typeof'VkCommandBuffer'
	local cmds = vkGet(VkCommandBuffer, vkassert, vk.vkAllocateCommandBuffers, device, info)
	--]]
	-- [[ I want to keep the pointer so ...
	local cmds = ffi.new(VkCommandBuffer_1)
	vkassert(vk.vkAllocateCommandBuffers, device, info, cmds)
	--]]

	local info = ffi.new(VkCommandBufferBeginInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
	info[0].flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT
	vkassert(vk.vkBeginCommandBuffer, cmds[0], info)

	callback(cmds[0])

	vkassert(vk.vkEndCommandBuffer, cmds[0])

	local submits = ffi.new(VkSubmitInfo_1)
	submits[0].sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO
	submits[0].commandBufferCount = 1
	submits[0].pCommandBuffers = cmds
	vkassert(vk.vkQueueSubmit, queue, 1, submits, nil)
	vkassert(vk.vkQueueWaitIdle, queue)
end

return VKSingleTimeCommand
