require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkFence = ffi.typeof'VkFence'
local makeVkFenceCreateInfo = makeStructCtor'VkFenceCreateInfo'


local VKFence = class()

function VKFence:init(args)
	local device = assert.index(args, 'device')
	args.device = nil
	device = device.obj or device
	device = device.id or device
	self.device = device

	self.id, self.idptr = vkGet(
		VkFence,
		vkassert,
		vk.vkCreateFence,
		device,
		makeVkFenceCreateInfo(args),
		nil
	)
end

function VKFence:destroy()
	if self.id then
		vk.vkDestroyFence(self.device, self.id, nil)
	end
	self.id = nil
end

VKFence.__gc = VKFence.destroy

return VKFence
