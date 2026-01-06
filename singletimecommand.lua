-- helper
local ffi = require 'ffi'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert

local VkCommandBufferAllocateInfo_1 = ffi.typeof'VkCommandBufferAllocateInfo[1]'
local VkCommandBuffer_1 = ffi.typeof'VkCommandBuffer[1]'
local VkCommandBufferBeginInfo_1 = ffi.typeof'VkCommandBufferBeginInfo[1]'
local VkSubmitInfo_1 = ffi.typeof'VkSubmitInfo[1]'


local function VKSingleTimeCommand(device, queue, commandPool, callback)
	--[[
	local vkGet = require 'vk.util'.vkGet
	local VkCommandBuffer = ffi.typeof'VkCommandBuffer'
	local cmds = vkGet(
		VkCommandBuffer,
		vkassert,
		vk.vkAllocateCommandBuffers,
		device,
		ffi.new(VkCommandBufferAllocateInfo_1, {{
			sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
			commandPool = commandPool,
			level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
			commandBufferCount = 1,
		}})
	)
	--]]
	-- [[ I want to keep the pointer so ...
	local cmds = ffi.new(VkCommandBuffer_1)
	vkassert(
		vk.vkAllocateCommandBuffers,
		device,
		ffi.new(VkCommandBufferAllocateInfo_1, {{
			sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
			commandPool = commandPool,
			level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
			commandBufferCount = 1,
		}}),
		cmds
	)
	--]]

	vkassert(
		vk.vkBeginCommandBuffer,
		cmds[0],
		ffi.new(VkCommandBufferBeginInfo_1, {{
			sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
			flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
		}})
	)

	callback(cmds[0])

	vkassert(vk.vkEndCommandBuffer, cmds[0])

	vkassert(
		vk.vkQueueSubmit,
		queue,
		1,
		ffi.new(VkSubmitInfo_1, {{
			sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO,
			commandBufferCount = 1,
			pCommandBuffers = cmds,
		}}),
		nil
	)
	vkassert(vk.vkQueueWaitIdle, queue)
end

return VKSingleTimeCommand
