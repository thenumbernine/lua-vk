require 'ext.gc'
local ffi = require 'ffi'
local table = require 'ext.table'
local class = require 'ext.class'
local assert = require 'ext.assert'
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

-- static method
local VkLayerProperties = ffi.typeof'VkLayerProperties'
function VKInstance:getLayerProps()
	local layerPropsVec = vkGetVector(VkLayerProperties, vkassert, vk.vkEnumerateInstanceLayerProperties)
	local layerProps = table()
	for i=0,#layerPropsVec-1 do
		local v = layerPropsVec.v + i
		layerProps:insert{
			layerName = ffi.string(v.layerName),--, vk.VK_MAX_EXTENSION_NAME_SIZE),
			description = ffi.string(v.description),--, vk.VK_MAX_DESCRIPTION_SIZE),
		}
	end
	return layerProps
end

-- static method
-- TODO actually generate SDL/vulkan and put it in the SDL header, or in a separate 'sdl.ffi.sdl3.vulkan' or something
local sdl = require 'sdl'
ffi.cdef[[
char const * const * SDL_Vulkan_GetInstanceExtensions(uint32_t * count);
]]
local uint32_t_1 = ffi.typeof'uint32_t[1]'
function VKInstance:getExts()
	--[[ SDL2?
	local asserteq = require 'ext.assert'.eq
	local function sdlvksafe(f, ...)
		asserteq(sdl.SDL_TRUE, f(...))
	end
	return vkGetVector('char const *', sdlvksafe, sdl.SDL_Vulkan_GetInstanceExtensions, window)
		:totable()
		:mapi(function(s) return ffi.string(s) end)
	--]]
	-- [[ SDL3
	local enabledExtensions = table()
	local count = uint32_t_1()
	local extstrs = assert.ne(sdl.SDL_Vulkan_GetInstanceExtensions(count), ffi.null)
	for i=0,count[0]-1 do
		enabledExtensions:insert(ffi.string(extstrs[i]))
	end
	return enabledExtensions
	--]]
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
