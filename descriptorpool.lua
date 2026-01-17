require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkDescriptorPool = ffi.typeof'VkDescriptorPool'
local makeVkDescriptorPoolCreateInfo = makeStructCtor(
	'VkDescriptorPoolCreateInfo',
	{
		{
			name = 'poolSizes',
			type = 'VkDescriptorPoolSize',
		},
	}
)


local VKDescriptorPool = class()

function VKDescriptorPool:init(args)
	local device = assert.index(args, 'device')
	args.device = nil
	device = device.obj or device
	device = device.id or device
	self.device = device

	self.id, self.idptr = vkGet(
		VkDescriptorPool,
		vkassert,
		vk.vkCreateDescriptorPool,
		device,
		makeVkDescriptorPoolCreateInfo(args),
		nil
	)
end

function VKDescriptorPool:destroy()
	if self.id then
		vk.vkDestroyDescriptorPool(self.device, self.id, nil)
	end
	self.id = nil
end

function VKDescriptorPool:__gc()
	return self:destroy()
end

return VKDescriptorPool
