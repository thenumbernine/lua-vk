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
	local device = assert.index(args, 'device')
	args.device = nil
	device = device.obj or device
	device = device.id or device
	self.device = device

	self.id = vkGet(
		VkSampler,
		vkassert,
		vk.vkCreateSampler,
		device,
		makeVkSamplerCreateInfo(args),
		nil
	)
end

function VKSampler:destroy()
	if self.id then
		vk.vkDestroySampler(self.device, self.id, nil)
	end
	self.id = nil
end

VKSampler.__gc = VKSampler.destroy

return VKSampler
