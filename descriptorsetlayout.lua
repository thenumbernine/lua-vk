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


local VKDescriptorSetLayout = class()

function VKDescriptorSetLayout:init(args)
	self.device = assert.index(args, 'device')
	args.device = nil

	self.id = vkGet(
		VkDescriptorSetLayout,
		nil,
		vk.vkCreateDescriptorSetLayout,
		self.device,
		makeVkDescriptorSetLayoutCreateInfo(args),
		nil
	)
end

function VKDescriptorSetLayout:destroy()
	if self.id then
		vk.vkDestroyDescriptorSetLayout(self.device, self.id, nil)
	end
	self.id = nil
end

VKDescriptorSetLayout.__gc = VKDescriptorSetLayout.destroy 

return VKDescriptorSetLayout 
