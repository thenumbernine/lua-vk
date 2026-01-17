require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkCommandPool = ffi.typeof'VkCommandPool'
local makeVkCommandPoolCreateInfo = makeStructCtor'VkCommandPoolCreateInfo'


local VKCommandPool = class()

function VKCommandPool:init(args)
	local device = assert.index(args, 'device')
	device = device.obj or device
	device = device.id or device
	self.device = device

	self.id, self.idptr = vkGet(
		VkCommandPool,
		vkassert,
		vk.vkCreateCommandPool,
		self.device,
		makeVkCommandPoolCreateInfo(args),
		nil
	)
end

function VKCommandPool:makeCmds(args)
	local VKCommandBuffer = require 'vk.commandbuffer'
	args.device = self.device
	args.commandPool = self.id
	return VKCommandBuffer(args)
end

function VKCommandPool:destroy(args)
	if self.id then
		vk.vkDestroyCommandPool(self.device, self.id, nil)
	end
	self.id = nil
end

function VKCommandPool:__gc()
	return self:destroy()
end

return VKCommandPool 
