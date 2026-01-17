-- the name implie one command buffer
-- but you can set .commandBufferCount to any value and .idptr will hold all the allocated buffers
require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkCommandBuffer_array = ffi.typeof'VkCommandBuffer[?]'
local makeVkCommandBufferAllocateInfo = makeStructCtor'VkCommandBufferAllocateInfo'


local VKCommandBuffer = class()

function VKCommandBuffer:init(args)
	local device = assert.index(args, 'device')
	args.device = nil
	local VulkanDevice = require 'vk.vulkandevice'
	if VulkanDevice:isa(device) then device = device.obj end
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
	-- for convenience
	self.id = self.idptr[0]
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
