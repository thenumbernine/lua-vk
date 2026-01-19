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


local VKDescPool = class()

function VKDescPool:init(args)
	self.device = assert.index(args, 'device')
	args.device = nil

	self.id, self.idptr = vkGet(
		VkDescriptorPool,
		vkassert,
		vk.vkCreateDescriptorPool,
		self.device.id,
		makeVkDescriptorPoolCreateInfo(args),
		nil
	)
end

function VKDescPool:makeDescSet(args)
	args.device = self.device
	args.descriptorPool = self
	local VKDescSet = require 'vk.descset'
	return VKDescSet(args)
end

function VKDescPool:destroy()
	if self.id then
		vk.vkDestroyDescriptorPool(self.device.id, self.id, nil)
	end
	self.id = nil
end

function VKDescPool:__gc()
	return self:destroy()
end

return VKDescPool
