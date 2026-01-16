require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkPipelineLayout = ffi.typeof'VkPipelineLayout'
local makeVkPipelineLayoutCreateInfo = makeStructCtor'VkPipelineLayoutCreateInfo'


local VKPipelineLayout = class()

function VKPipelineLayout:init(args)
	self.device = assert.index(args, 'device')
	self.id = vkGet(
		VkPipelineLayout,
		vkassert,
		vk.vkCreatePipelineLayout,
		self.device,
		makeVkPipelineLayoutCreateInfo(args),
		nil
	)
end

function VKPipelineLayout:destroy()
	if self.id then
		vk.vkDestroyPipelineLayout(self.device, self.id, nil)
	end
	self.id = nil
end

VKPipelineLayout.__gc = VKPipelineLayout.destroy


return VKPipelineLayout
