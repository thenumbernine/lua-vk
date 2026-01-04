--[[
this and swapchain have similar dtor paired with device, and createinfo
surface is sort of similar, paired with instance, but no createinfo
--]]
require 'ext.gc'	-- make sure luajit can __gc lua-tables
local ffi = require 'ffi'
local class = require 'ext.class'
local assertindex = require 'ext.assert'.index
local assertne = require 'ext.assert'.ne
local vk = require 'vk'
local VKDevice = require 'vk.device'

local vkassert = require 'vk.util'.vkassert
local vkGetVector = require 'vk.util'.vkGetVector


local VkBuffer_1 = ffi.typeof'VkBuffer[1]'


local VKBuffer = class()

VKBuffer.createType = 'VkBufferCreateInfo'
require 'vk.util'.addInitFromArgs(VKBuffer)

function VKBuffer:init(args)
	local device = assertindex(args, 'device')
	if VKDevice:isa(device) then device = device.id end
	
	self.device = device

	local info = self:initFromArgs(args)
	local ptr = ffi.new(VkBuffer_1)
	vkassert(vk.vkCreateBuffer, device, info, nil, ptr)
	self.id = ptr[0]
end

function VKBuffer:destroy()
	if self.device == nil and self.id == nil then return end
	assertne(self.device, nil)
	assertne(self.id, nil)
	vk.vkDestroyBuffer(self.device, self.id, nil)
	self.id = nil
	self.device = nil
end

return VKBuffer
