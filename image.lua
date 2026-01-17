require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local vkResult = require 'vk.util'.vkResult
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkImage = ffi.typeof'VkImage'
local VkMemoryRequirements = ffi.typeof'VkMemoryRequirements'
local makeVkImageCreateInfo = makeStructCtor'VkImageCreateInfo'


local VKImage = class()

function VKImage:init(args)
	local device = assert.index(args, 'device')
	args.device = nil
	local VulkanDevice = require 'vk.vulkandevice'
	if VulkanDevice:isa(device) then device = device.obj end
	local VKDevice = require 'vk.device'
	if VKDevice:isa(device) then device = device.id end
	self.device = device

	self.id, self.idptr = vkGet(
		VkImage,
		vkassert,
		vk.vkCreateImage,
		device,
		makeVkImageCreateInfo(args),
		nil
	)
end

function VKImage:getMemReq()
	return vkGet(
		VkMemoryRequirements,
		nil,
		vk.vkGetImageMemoryRequirements,
		self.device,
		self.id
	)
end

function VKImage:bindMemory(mem)
	return vkResult(
		vk.vkBindImageMemory(
			self.device,
			self.id,
			mem,
			0
		),
		'vkBindImageMemory'
	)
end

function VKImage:destroy()
	if self.id then
		vk.vkDestroyImage(self.device, self.id, nil)
	end
	self.id = nil
end

function VKImage:__gc()
	return self:destroy()
end

return VKImage
