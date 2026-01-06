-- another one that doesn't use raii for anything
-- but it does use the info ctor
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


local VkImage = ffi.typeof'VkImage'
local VkSwapchainKHR = ffi.typeof'VkSwapchainKHR'


local VKSwapchain = class()

VKSwapchain.createType = 'VkSwapchainCreateInfoKHR'	-- for vk create
require 'vk.util'.addInitFromArgs(VKSwapchain)

function VKSwapchain:init(args)
	local device = assertindex(args, 'device')
	if VKDevice:isa(device) then device = device.id end
	self.device = device
	self.id = vkGet(
		VkSwapchainKHR,
		vkassert,
		vk.vkCreateSwapchainKHR,
		device,
		self:initFromArgs(args),
		nil
	)
end

function VKSwapchain:getImages(device)
	if VKDevice:isa(device) then device = device.id end
	return vkGetVector(VkImage, vkassert, vk.vkGetSwapchainImagesKHR, device, self.id)
end

function VKSwapchain:destroy()
	if self.device == nil and self.id == nil then return end
	assertne(self.device, nil)
	assertne(self.id, nil)
	vk.vkDestroySwapchainKHR(self.device, self.id, nil)
	self.id = nil
	self.device = nil
end

VKSwapchain.__gc = VKSwapchain.destroy

return VKSwapchain
