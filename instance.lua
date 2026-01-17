require 'ext.gc'
local ffi = require 'ffi'
local table = require 'ext.table'
local class = require 'ext.class'
local vk = require 'vk'

local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local vkGetVector = require 'vk.util'.vkGetVector
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkInstance = ffi.typeof'VkInstance'
local VkPhysicalDevice = ffi.typeof'VkPhysicalDevice'

local makeVkApplicationInfo = makeStructCtor'VkApplicationInfo'
local makeVkInstanceCreateInfo = makeStructCtor(
	'VkInstanceCreateInfo',
	{
		{
			name = 'applicationInfo',
			ptrname = 'pApplicationInfo',
			gen = function(x)
				return makeVkApplicationInfo(x)
			end,
			notarray = true,
		},
		-- also in device:
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


local VKInstance = class() 

function VKInstance:init(args)
	self.id, self.idptr = vkGet(
		VkInstance,
		vkassert,
		vk.vkCreateInstance,
		makeVkInstanceCreateInfo(args),
		nil
	)
end

function VKInstance:getPhysDevs()
	local VKPhysDev = require 'vk.physdev'
	local physDevs = table()
	local physDevIDs = vkGetVector(
		VkPhysicalDevice,
		vkassert,
		vk.vkEnumeratePhysicalDevices,
		self.id
	)
	for i=0,#physDevIDs-1 do
		physDevs:insert(VKPhysDev(physDevIDs.v[i]))
	end
	return physDevs
end

function VKInstance:getProcAddr(name, ctype)
	ctype = ctype or 'PFN_'..name
	local ptr = vk.vkGetInstanceProcAddr(self.id, name)
	ptr = ffi.cast(ctype, ptr)
	return ptr 
end

function VKInstance:destroy()
	if self.id then
		vk.vkDestroyInstance(self.id, nil)
	end
	self.id = nil
end

function VKInstance:__gc()
	return self:destroy()
end

return VKInstance
