-- another one that doesn't use raii for anything
-- but it does use the info ctor
require 'ext.gc'	-- make sure luajit can __gc lua-tables
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local VKDevice = require 'vk.device'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local vkGetVector = require 'vk.util'.vkGetVector
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkImage = ffi.typeof'VkImage'
local VkSwapchainKHR = ffi.typeof'VkSwapchainKHR'
local makeVkSwapchainCreateInfoKHR = makeStructCtor(
	'VkSwapchainCreateInfoKHR',
	{
		{
			name = 'queueFamilyIndices',
			ptrname = 'pQueueFamilyIndices',
			countname = 'queueFamilyIndexCount',
			type = 'uint32_t',
		},
	}
)


local VKSwapchain = class()

function VKSwapchain:init(args)
	local device = assert.index(args, 'device')
	if VKDevice:isa(device) then device = device.id end
	self.device = device
	self.id, self.idptr = vkGet(
		VkSwapchainKHR,
		vkassert,
		vk.vkCreateSwapchainKHR,
		device,
		makeVkSwapchainCreateInfoKHR(args),
		nil
	)
end

function VKSwapchain:getImages()
	return vkGetVector(
		VkImage,
		vkassert,
		vk.vkGetSwapchainImagesKHR,
		self.device,
		self.id
	)
end

function VKSwapchain:destroy()
	if self.id then
		vk.vkDestroySwapchainKHR(self.device, self.id, nil)
	end
	self.id = nil
end

function VKSwapchain:__gc()
	return self:destroy()
end

return VKSwapchain
