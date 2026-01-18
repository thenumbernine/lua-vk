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


local VKCommandBuffer = class()

function VKCommandBuffer:init(args)
	local device = assert.index(args, 'device')
	args.device = nil
	local VKDevice = require 'vk.device'
	if VKDevice:isa(device) then device = device.id end
	self.device = device

	-- needed for destroy
	self.commandPool = assert.index(args, 'commandPool')

	args.commandBufferCount = args.commandBufferCount or 1
	self.count = args.commandBufferCount

	-- not sure what to call this, .id, .ids, .idptr ...
	-- same as vk.descriptorsets
	self.idptr = VkCommandBuffer_array(self.count)
	vkassert(
		vk.vkAllocateCommandBuffers,
		device,
		makeVkCommandBufferAllocateInfo(args),
		self.idptr
	)
	self.id = self.idptr[0]
end

-- only runs on the first one i.e. .id
function VKCommandBuffer:begin(args)
	return vkResult(
		vk.vkBeginCommandBuffer(
			self.id,
			makeVkCommandBufferBeginInfo(args)
		),
		'vkBeginCommandBuffer'
	)
end

function VKCommandBuffer:done()	-- "end"
	return vkResult(
		vk.vkEndCommandBuffer(self.id),
		'vkEndCommandBuffer'
	)
end

function VKCommandBuffer:reset()
	return vkResult(
		vk.vkResetCommandBuffer(self.id, 0),
		'vkResetCommandBuffer'
	)
end

VKCommandBuffer.makeVkImageMemoryBarrier = makeStructCtor'VkImageMemoryBarrier'
function VKCommandBuffer:pipelineBarrier(...)
	return vk.vkCmdPipelineBarrier(self.id, ...)
end

VKCommandBuffer.VkBufferCopy = ffi.typeof'VkBufferCopy'
function VKCommandBuffer:copyBuffer(...)
	return vk.vkCmdCopyBuffer(self.id, ...)
end

VKCommandBuffer.VkBufferImageCopy = ffi.typeof'VkBufferImageCopy'
function VKCommandBuffer:copyBufferToImage(...)
	return vk.vkCmdCopyBufferToImage(self.id, ...)
end

VKCommandBuffer.VkImageBlit = ffi.typeof'VkImageBlit'
function VKCommandBuffer:blitImage(...)
	return vk.vkCmdBlitImage(self.id, ...)
end

VKCommandBuffer.makeVkRenderPassBeginInfo = makeVkRenderPassBeginInfo 
function VKCommandBuffer:beginRenderPass(...)
	return vk.vkCmdBeginRenderPass(self.id, ...)
end

function VKCommandBuffer:endRenderPass()
	return vk.vkCmdEndRenderPass(self.id)
end

function VKCommandBuffer:bindPipeline(...)
	return vk.vkCmdBindPipeline(self.id, ...)
end

VKCommandBuffer.VkViewport = ffi.typeof'VkViewport'
function VKCommandBuffer:setViewport(...)
	return vk.vkCmdSetViewport(self.id, ...)
end

VKCommandBuffer.VkRect2D = ffi.typeof'VkRect2D'
function VKCommandBuffer:setScissors(...)
	return vk.vkCmdSetScissor(self.id, ...)
end

VKCommandBuffer.VkBuffer_array = ffi.typeof'VkBuffer[?]'
VKCommandBuffer.VkDeviceSize_array = ffi.typeof'VkDeviceSize[?]'
function VKCommandBuffer:bindVertexBuffers(...)
	return vk.vkCmdBindVertexBuffers(self.id, ...)
end

function VKCommandBuffer:bindIndexBuffer(...)
	return vk.vkCmdBindIndexBuffer(self.id, ...)
end

function VKCommandBuffer:bindDescriptorSets(...)
	return vk.vkCmdBindDescriptorSets(self.id, ...)
end

function VKCommandBuffer:drawIndexed(...)
	return vk.vkCmdDrawIndexed(self.id, ...)
end

function VKCommandBuffer:destroy()
	if self.idptr then
		vk.vkFreeCommandBuffers(self.device, self.commandPool, self.count, self.idptr)
	end
	self.id = nil
	self.idptr = nil
end

function VKCommandBuffer:__gc()
	return self:destroy()
end

return VKCommandBuffer
