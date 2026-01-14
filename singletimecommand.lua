-- helper
local ffi = require 'ffi'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert

local VkCommandBufferAllocateInfo = ffi.typeof'VkCommandBufferAllocateInfo'
local VkCommandBuffer_1 = ffi.typeof'VkCommandBuffer[1]'
local VkCommandBufferBeginInfo = ffi.typeof'VkCommandBufferBeginInfo'
local VkSubmitInfo = ffi.typeof'VkSubmitInfo'


local self = {}	-- cuz i guess I need an object and I'm too lazy to rename it to a scope var name
_G.retainVKSingleTimeCommand = self
local function VKSingleTimeCommand(device, queue, commandPool, callback)
	self.info = VkCommandBufferAllocateInfo()
	self.info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
	self.info.commandPool = commandPool
	self.info.level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY
	self.info.commandBufferCount = 1
	--[[
	local vkGet = require 'vk.util'.vkGet
	local VkCommandBuffer = ffi.typeof'VkCommandBuffer'
	local cmds = vkGet(VkCommandBuffer, vkassert, vk.vkAllocateCommandBuffers, device, self.info)
	--]]
	-- [[ I want to keep the pointer so ...
	self.cmds = VkCommandBuffer_1()
	vkassert(vk.vkAllocateCommandBuffers, device, self.info, self.cmds)
	--]]
	self.info = nil

	self.info = VkCommandBufferBeginInfo()
	self.info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
	self.info.flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT
	vkassert(vk.vkBeginCommandBuffer, self.cmds[0], self.info)
	self.info = nil

	callback(self.cmds[0])

	vkassert(vk.vkEndCommandBuffer, self.cmds[0])

	self.info = VkSubmitInfo()
	self.info.sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO
	self.info.commandBufferCount = 1
	self.info.pCommandBuffers = self.cmds
	vkassert(vk.vkQueueSubmit, queue, 1, self.info, nil)
	self.info = nil

	vkassert(vk.vkQueueWaitIdle, queue)

	vk.vkFreeCommandBuffers(device, commandPool, 1, self.cmds)

	self.cmds = nil
end

return VKSingleTimeCommand
