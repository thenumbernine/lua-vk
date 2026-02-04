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


local VKCmdPool = class()

function VKCmdPool:init(args)
	self.device = assert.index(args, 'device')
	args.device = nil

	self.id, self.idptr = vkGet(
		VkCommandPool,
		vkassert,
		vk.vkCreateCommandPool,
		self.device.id,
		makeVkCommandPoolCreateInfo(args),
		nil
	)
end

function VKCmdPool:makeCmds(args)
	local VKCmdBuf = require 'vk.cmdbuf'
	args.device = self.device
	args.commandPool = self
	return self.device:addAutoDestroy(VKCmdBuf(args))
end

function VKCmdPool:destroy(args)
	if self.id then
		vk.vkDestroyCommandPool(self.device.id, self.id, nil)
	end
	self.id = nil
	self.idptr = nil
end

function VKCmdPool:__gc()
	return self:destroy()
end

return VKCmdPool
