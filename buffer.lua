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
local vkGet = require 'vk.util'.vkGet
local vkGetVector = require 'vk.util'.vkGetVector


local VkBuffer = ffi.typeof'VkBuffer'


local VKBuffer = class()

VKBuffer.createType = ffi.typeof'VkBufferCreateInfo'
require 'vk.util'.addInitFromArgs(VKBuffer)

function VKBuffer:init(args)
	local device = assertindex(args, 'device')
	if VKDevice:isa(device) then device = device.id end
	
	self.device = device

	self.info = self:initFromArgs(args)
	self.id = vkGet(VkBuffer, vkassert, vk.vkCreateBuffer, device, self.info, nil)
	self.info = nil
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
