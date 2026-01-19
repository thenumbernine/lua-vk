require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkPipelineLayout = ffi.typeof'VkPipelineLayout'
local makeVkPipelineLayoutCreateInfo = makeStructCtor(
	'VkPipelineLayoutCreateInfo',
	{
		{
			name = 'setLayouts',
			type = 'VkDescriptorSetLayout',
			gen = function(x)
				-- convert VKDescriptorSetLayout's to VkDescriptorSetLayout's
				return x.id or x
			end,
		},
	}
)


local VKPipelineLayout = class()

function VKPipelineLayout:init(args)
	self.device = assert.index(args, 'device')
	args.device = nil

	self.id, self.idptr = vkGet(
		VkPipelineLayout,
		vkassert,
		vk.vkCreatePipelineLayout,
		self.device.id,
		makeVkPipelineLayoutCreateInfo(args),
		nil
	)
end

function VKPipelineLayout:destroy()
	if self.id then
		vk.vkDestroyPipelineLayout(self.device.id, self.id, nil)
	end
	self.id = nil
	self.idptr = nil
end

function VKPipelineLayout:__gc()
	return self:destroy()
end

return VKPipelineLayout
