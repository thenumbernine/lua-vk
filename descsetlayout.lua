require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkDescriptorSetLayout = ffi.typeof'VkDescriptorSetLayout'
local makeVkDescriptorSetLayoutCreateInfo = makeStructCtor(
	'VkDescriptorSetLayoutCreateInfo',
	{
		{
			name = 'bindings',
			type = 'VkDescriptorSetLayoutBinding',
		},
	}
)


local VKDescSetLayout = class()

function VKDescSetLayout:init(args)
	self.device = assert.index(args, 'device')
	args.device = nil

	self.id, self.idptr = vkGet(
		VkDescriptorSetLayout,
		nil,
		vk.vkCreateDescriptorSetLayout,
		self.device.id,
		makeVkDescriptorSetLayoutCreateInfo(args),
		nil
	)
end

function VKDescSetLayout:destroy()
	if self.id then
		vk.vkDestroyDescriptorSetLayout(self.device.id, self.id, nil)
	end
	self.id = nil
	self.idptr = nil
end

function VKDescSetLayout:__gc()
	return self:destroy()
end

return VKDescSetLayout
