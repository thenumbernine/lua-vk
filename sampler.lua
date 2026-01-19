require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkSampler = ffi.typeof'VkSampler'
local makeVkSamplerCreateInfo = makeStructCtor'VkSamplerCreateInfo'


local VKSampler = class()

function VKSampler:init(args)
	self.device = assert.index(args, 'device')
	args.device = nil

	self.id, self.idptr = vkGet(
		VkSampler,
		vkassert,
		vk.vkCreateSampler,
		self.device.id,
		makeVkSamplerCreateInfo(args),
		nil
	)
end

function VKSampler:destroy()
	if self.id then
		vk.vkDestroySampler(self.device.id, self.id, nil)
	end
	self.id = nil
	self.idptr = nil
end

function VKSampler:__gc()
	return self:destroy()
end

return VKSampler
