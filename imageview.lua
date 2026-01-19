require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkImageView = ffi.typeof'VkImageView'
local makeVkImageViewCreateInfo = makeStructCtor'VkImageViewCreateInfo'


local VKImageView = class()

function VKImageView:init(args)
	self.device = assert.index(args, 'device')
	args.device = nil

	self.id, self.idptr = vkGet(
		VkImageView,
		vkassert,
		vk.vkCreateImageView,
		self.device.id,
		makeVkImageViewCreateInfo(args),
		nil
	)
end

function VKImageView:destroy()
	if self.id then
		vk.vkDestroyImageView(self.device.id, self.id, nil)
	end
	self.id = nil
	self.idptr = nil
end

function VKImageView:__gc()
	return self:destroy()
end

return VKImageView
