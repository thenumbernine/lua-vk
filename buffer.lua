--[[
this and swapchain have similar dtor paired with device, and createinfo
surface is sort of similar, paired with instance, but no createinfo
--]]
local ffi = require 'ffi'
local GCWrapper = require 'ffi.gcwrapper.gcwrapper'
local assertindex = require 'ext.assert'.index
local assertne = require 'ext.assert'.ne
local vk = require 'vk'
local VKDevice = require 'vk.device'

local vkassert = require 'vk.util'.vkassert
local vkGetVector = require 'vk.util'.vkGetVector

local ctype = 'VkBuffer'

local dtortype = 'autorelease_'..ctype..'_dtor_t'
require 'struct'{
	name = dtortype,
	fields = {
		{name='buffer', type=ctype..'[1]'},
		{name='device', type='VkDevice'},
	},
}

local VKBuffer = GCWrapper{
	gctype = 'autorelease_'..ctype..'_ptr_t',
	ctype = dtortype,
	release = function(ptr)
		if ptr[0].device == nil and ptr[0].buffer[0] == nil then return end
		assertne(ptr[0].device, nil)
		assertne(ptr[0].buffer[0], nil)
		vk.vkDestroyBuffer(ptr[0].device, ptr[0].buffer[0], nil)
	end,
}:subclass()

VKBuffer.createType = 'VkBufferCreateInfo'
require 'vk.util'.addInitFromArgs(VKBuffer)

function VKBuffer:init(args)
	local device = assertindex(args, 'device')
	if VKDevice:isa(device) then device = device.id end
	
	local dtorinit = ffi.new(dtortype)
	dtorinit.device = device

	local info = self:initFromArgs(args)
	vkassert(vk.vkCreateBuffer, device, info, nil, dtorinit.buffer)

	VKBuffer.super.init(self, dtorinit)
	
	self.id = self.gc.ptr[0].buffer[0]

end

function VKBuffer:destroy()
	local ptr = self.gc.ptr
	if ptr[0].device == nil and ptr[0].buffer[0] == nil then return end
	assertne(ptr[0].device, nil)
	assertne(ptr[0].buffer[0], nil)
	vk.vkDestroyBuffer(ptr[0].device, ptr[0].buffer[0], nil)
	ptr[0].buffer[0] = nil
	ptr[0].device = nil
end

return VKBuffer
