local ffi = require 'ffi'
local class = require 'ext.class'
local assertindex = require 'ext.assert'.index
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor
local VKPhysDev = require 'vk.physdev'


local makeVkDeviceQueueCreateInfo = makeStructCtor(
	'VkDeviceQueueCreateInfo',
	{
		{
			name = 'queuePriorities',
			ptrname = 'pQueuePriorities',
			countname = 'queueCount',
			type = 'float',
		},
	}
)


local VkDevice = ffi.typeof'VkDevice'

local makeVkDeviceCreateInfo = makeStructCtor(
	'VkDeviceCreateInfo',
	{
		{
			name = 'queueCreateInfos',
			type = 'VkDeviceQueueCreateInfo',
			gen = makeVkDeviceQueueCreateInfo,
		},
		{
			name = 'enabledFeatures',
			ptrname = 'pEnabledFeatures',
			type = 'VkPhysicalDeviceFeatures',
			notarray = true,
		},
		-- also in instance:
		{
			name = 'enabledLayers',
			ptrname = 'ppEnabledLayerNames',
			countname = 'enabledLayerCount',
			type = 'char const*',
			gen = function(x)
				return ffi.cast('char const*', x)
			end,
		},
		{
			name = 'enabledExtensions',
			ptrname = 'ppEnabledExtensionNames',
			countname = 'enabledExtensionCount',
			type = 'char const*',
			gen = function(x)
				return ffi.cast('char const*', x)
			end,
		},
	}
)


local VKDevice = class()

function VKDevice:init(args)
	-- can I still pass args to ffi.new?  will it ignore extra fields?  seems alright ...
	local physDev = assertindex(args, 'physDev')
	args.physDev = nil
	if VKPhysDev:isa(physDev) then physDev = physDev.id end

	self.id = vkGet(
		VkDevice,
		vkassert,
		vk.vkCreateDevice,
		physDev,
		makeVkDeviceCreateInfo(args),
		nil
	)
end

function VKDevice:waitIdle()
	vkassert(vk.vkDeviceWaitIdle, self.id)
end

function VKDevice:destroy()
	if self.id then
		vk.vkDestroyDevice(self.id, nil)
	end
	self.id = nil
end

return VKDevice
