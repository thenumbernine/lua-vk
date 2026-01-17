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
	local device = assert.index(args, 'device')
	args.device = nil
	local VulkanDevice = require 'vk.device'
	if VulkanDevice:isa(device) then device = device.obj end
	local VKDevice = require 'vk.device'
	if VKDevice:isa(device) then device = device.id end
	self.device = device

	self.id, self.idptr = vkGet(
		VkImageView,
		vkassert,
		vk.vkCreateImageView,
		device,
		makeVkImageViewCreateInfo(args),
		nil
	)
end

function VKImageView:destroy()
	if self.id then
		vk.vkDestroyImageView(self.device, self.id, nil)
	end
	self.id = nil
end

VKImageView.__gc = VKImageView.destroy

return VKImageView
