require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor


local void_ptr = ffi.typeof'void*'
local VkDeviceMemory = ffi.typeof'VkDeviceMemory'
local makeVkMemoryAllocateInfo = makeStructCtor'VkMemoryAllocateInfo'


local VKMem = class()

function VKMem:init(args)
	self.device = assert.index(args, 'device')
	args.device = nil

	self.id, self.idptr = vkGet(
		VkDeviceMemory,
		vkassert,
		vk.vkAllocateMemory,
		self.device.id,
		makeVkMemoryAllocateInfo(args),
		nil
	)
end

function VKMem:map(bufferSize)
	return vkGet(
		void_ptr,
		vkassert,
		vk.vkMapMemory,
		self.device.id,
		self.id,
		0,
		bufferSize,
		0)
end

function VKMem:unmap()
	vk.vkUnmapMemory(self.device.id, self.id)
end

function VKMem:destroy()
	if self.id then
		vk.vkFreeMemory(self.device.id, self.id, nil)
	end
	self.id = nil
	self.idptr = nil
end

function VKMem:__gc()
	return self:destroy()
end

return VKMem
