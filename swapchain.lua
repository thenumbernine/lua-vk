require 'ext.gc'	-- make sure luajit can __gc lua-tables
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
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
	self.device = assert.index(args, 'device')
	args.device = nil

	self.id, self.idptr = vkGet(
		VkSwapchainKHR,
		vkassert,
		vk.vkCreateSwapchainKHR,
		self.device.id,
		makeVkSwapchainCreateInfoKHR(args),
		nil
	)
end

function VKSwapchain:getImages()
	return vkGetVector(
		VkImage,
		vkassert,
		vk.vkGetSwapchainImagesKHR,
		self.device.id,
		self.id
	)
	-- [[ Lua-ize
	:totable()
	:mapi(function(imageID)
		return self.device:makeImageFromID(imageID)
	end)
	--]]
end

function VKSwapchain:destroy()
	if self.id then
		vk.vkDestroySwapchainKHR(self.device.id, self.id, nil)
	end
	self.id = nil
end

function VKSwapchain:__gc()
	return self:destroy()
end

return VKSwapchain
