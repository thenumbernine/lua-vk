require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkFramebuffer = ffi.typeof'VkFramebuffer'
local makeVkFramebufferCreateInfo = makeStructCtor(
	'VkFramebufferCreateInfo',
	{
		{
			name = 'attachments',
			type = 'VkImageView',
		},
	}
)


local VKFramebuffer = class()

function VKFramebuffer:init(args)
	self.device = assert.index(args, 'device')
	args.device = nil

	self.id, self.idptr = vkGet(
		VkFramebuffer,
		vkassert,
		vk.vkCreateFramebuffer,
		self.device,
		makeVkFramebufferCreateInfo(args),
		nil
	)
end

function VKFramebuffer:destroy()
	if self.id then
		vk.vkDestroyFramebuffer(self.device, self.id, nil)
	end
	self.id = nil
end

function VKFramebuffer:__gc()
	return self:destroy()
end

return VKFramebuffer 
