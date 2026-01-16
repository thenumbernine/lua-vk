--[[
this and swapchain have similar dtor paired with device, and createinfo
surface is sort of similar, paired with instance, but no createinfo
--]]
require 'ext.gc'	-- make sure luajit can __gc lua-tables
local ffi = require 'ffi'
local class = require 'ext.class'
local assertindex = require 'ext.assert'.index
local vk = require 'vk'
local VKDevice = require 'vk.device'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet


local VkBuffer = ffi.typeof'VkBuffer'


local VKBuffer = class()

VKBuffer.createType = ffi.typeof'VkBufferCreateInfo'
require 'vk.util'.addInitFromArgs(VKBuffer)

function VKBuffer:init(args)
	local device = assertindex(args, 'device')
	if VKDevice:isa(device) then device = device.id end
	
	self.device = device

	self.id = vkGet(VkBuffer, vkassert, vk.vkCreateBuffer, device, self:initFromArgs(args), nil)
end

function VKBuffer:destroy()
	if self.id then
		vk.vkDestroyBuffer(self.device, self.id, nil)
	end
	self.id = nil
end

return VKBuffer
