require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkSemaphore = ffi.typeof'VkSemaphore'
local makeVkSemaphoreCreateInfo = makeStructCtor'VkSemaphoreCreateInfo'


local VKSemaphore = class()

function VKSemaphore:init(args)
	self.device = assert.index(args, 'device')
	args.device = nil

	self.id, self.idptr = vkGet(
		VkSemaphore,
		vkassert,
		vk.vkCreateSemaphore,
		self.device.id,
		makeVkSemaphoreCreateInfo(),
		nil
	)
end

function VKSemaphore:destroy()
	if self.id then
		vk.vkDestroySemaphore(self.device.id, self.id, nil)
	end
	self.id = nil
	self.idptr = nil
end

function VKSemaphore:__gc()
	return self:destroy()
end

return VKSemaphore
