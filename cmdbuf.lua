-- the name implie one command buffer
-- but you can set .commandBufferCount to any value and .idptr will hold all the allocated buffers
require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkResult = require 'vk.util'.vkResult
local makeStructCtor = require 'vk.util'.makeStructCtor
local makeTableToArray = require 'vk.util'.makeTableToArray


local VkCommandBuffer_array = ffi.typeof'VkCommandBuffer[?]'
local makeVkCommandBufferAllocateInfo = makeStructCtor'VkCommandBufferAllocateInfo'
local makeVkCommandBufferBeginInfo = makeStructCtor'VkCommandBufferBeginInfo'

local makeVkRenderPassBeginInfo = makeStructCtor(
	'VkRenderPassBeginInfo',
	{
		{
			name = 'clearValues',
			type = 'VkClearValue',
		},
	}
)
local makeVkClearValueArray = makeTableToArray'VkClearValue'


local VKCmdBuf = class()

function VKCmdBuf:init(args)
	self.device = assert.index(args, 'device')
	args.device = nil

	self.commandPool = assert.index(args, 'commandPool')
	args.commandPool = self.commandPool.id

	args.commandBufferCount = args.commandBufferCount or 1
	self.count = args.commandBufferCount

	-- not sure what to call this, .id, .ids, .idptr ...
	-- same as vk.descsets
	self.idptr = VkCommandBuffer_array(self.count)
	vkassert(
		vk.vkAllocateCommandBuffers,
		self.device.id,
		makeVkCommandBufferAllocateInfo(args),
		self.idptr
	)
	self.id = self.idptr[0]
end

-- only runs on the first one i.e. .id
VKCmdBuf.makeVkCommandBufferBeginInfo = makeVkCommandBufferBeginInfo
function VKCmdBuf:begin(...)
	return vkResult(vk.vkBeginCommandBuffer(self.id, ...), 'vkBeginCommandBuffer')
end

function VKCmdBuf:done()	-- "end"
	return vkResult(vk.vkEndCommandBuffer(self.id), 'vkEndCommandBuffer')
end

function VKCmdBuf:reset()
	return vkResult(vk.vkResetCommandBuffer(self.id, 0), 'vkResetCommandBuffer')
end

VKCmdBuf.makeVkImageMemoryBarrier = makeStructCtor'VkImageMemoryBarrier'
function VKCmdBuf:pipelineBarrier(...)
	return vk.vkCmdPipelineBarrier(self.id, ...)
end

VKCmdBuf.VkBufferCopy = ffi.typeof'VkBufferCopy'
function VKCmdBuf:copyBuffer(...)
	return vk.vkCmdCopyBuffer(self.id, ...)
end

VKCmdBuf.VkBufferImageCopy = ffi.typeof'VkBufferImageCopy'
function VKCmdBuf:copyBufferToImage(...)
	return vk.vkCmdCopyBufferToImage(self.id, ...)
end

VKCmdBuf.VkImageBlit = ffi.typeof'VkImageBlit'
function VKCmdBuf:blitImage(...)
	return vk.vkCmdBlitImage(self.id, ...)
end

VKCmdBuf.makeVkRenderPassBeginInfo = makeVkRenderPassBeginInfo
VKCmdBuf.makeVkClearValueArray = makeVkClearValueArray
function VKCmdBuf:beginRenderPass(...)
	return vk.vkCmdBeginRenderPass(self.id, ...)
end

function VKCmdBuf:endRenderPass()
	return vk.vkCmdEndRenderPass(self.id)
end

function VKCmdBuf:bindPipeline(...)
	return vk.vkCmdBindPipeline(self.id, ...)
end

VKCmdBuf.VkViewport = ffi.typeof'VkViewport'
function VKCmdBuf:setViewport(...)
	return vk.vkCmdSetViewport(self.id, ...)
end

VKCmdBuf.VkRect2D = ffi.typeof'VkRect2D'
function VKCmdBuf:setScissors(...)
	return vk.vkCmdSetScissor(self.id, ...)
end

VKCmdBuf.VkBuffer_array = ffi.typeof'VkBuffer[?]'
VKCmdBuf.VkDeviceSize_array = ffi.typeof'VkDeviceSize[?]'
function VKCmdBuf:bindVertexBuffers(...)
	return vk.vkCmdBindVertexBuffers(self.id, ...)
end

function VKCmdBuf:bindIndexBuffer(...)
	return vk.vkCmdBindIndexBuffer(self.id, ...)
end

function VKCmdBuf:bindDescriptorSets(...)
	return vk.vkCmdBindDescriptorSets(self.id, ...)
end

function VKCmdBuf:drawIndexed(...)
	return vk.vkCmdDrawIndexed(self.id, ...)
end

function VKCmdBuf:destroy()
	if self.idptr then
		vk.vkFreeCommandBuffers(self.device.id, self.commandPool.id, self.count, self.idptr)
	end
	self.id = nil
	self.idptr = nil
end

function VKCmdBuf:__gc()
	return self:destroy()
end

return VKCmdBuf
