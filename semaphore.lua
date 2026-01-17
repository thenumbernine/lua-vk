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
	local device = assert.index(args, 'device')
	args.device = nil
	device = device.obj or device
	device = device.id or device
	self.device = device

	-- keep the [1] ptr for later, cuz some ppl want ptrs-to-id
	self.id, self.idptr = vkGet(
		VkSemaphore,
		vkassert,
		vk.vkCreateSemaphore,
		device,
		makeVkSemaphoreCreateInfo(),
		nil
	)
end

function VKSemaphore:destroy()
	if self.id then
		vk.vkDestroySemaphore(self.device, self.id, nil) 
	end
	self.id = nil
end

function VKSemaphore:__gc()
	return self:destroy()
end

return VKSemaphore
