require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkPipeline = ffi.typeof'VkPipeline'
local makeVkGraphicsPipelineCreateInfo = makeStructCtor'VkGraphicsPipelineCreateInfo'


local VKPipeline = class()

function VKPipeline:init(args)
	self.device = assert.index(args, 'device')
	self.id = vkGet(
		VkPipeline,
		vkassert,
		vk.vkCreateGraphicsPipelines,
		self.device,
		nil,
		1,
		makeVkGraphicsPipelineCreateInfo(args),
		nil
	)
end

function VKPipeline:destroy()
	if self.id then
		vk.vkDestroyPipeline(self.device, self.id, nil)
	end
	self.id = nil
end

VKPipeline.__gc = VKPipeline.destroy

return VKPipeline
