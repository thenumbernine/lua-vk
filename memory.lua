require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkDeviceMemory = ffi.typeof'VkDeviceMemory'
local makeVkMemoryAllocateInfo = makeStructCtor'VkMemoryAllocateInfo'


local VKMemory = class()

function VKMemory:init(args)
	local device = assert.index(args, 'device')
	args.device = nil
	local VulkanDevice = require 'vk.vulkandevice'
	if VulkanDevice:isa(device) then device = device.obj end
	local VKDevice = require 'vk.device'
	if VKDevice:isa(device) then device = device.id end
	self.device = device

	self.id, self.idptr = vkGet(
		VkDeviceMemory,
		vkassert,
		vk.vkAllocateMemory,
		device,
		makeVkMemoryAllocateInfo(args),
		nil
	)
end

function VKMemory:destroy()
	if self.id then
		vk.vkFreeMemory(self.device, self.id, nil)
	end
	self.id = nil
end

function VKMemory:__gc()
	return self:destroy()
end

return VKMemory
