-- helper, not wrapper
local ffi = require 'ffi'
local class = require 'ext.class'
local table = require 'ext.table'
local assertne = require 'ext.assert'.ne
local vector = require 'ffi.cpp.vector-lua'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGetVector = require 'vk.util'.vkGetVector
local makeStructCtor = require 'vk.util'.makeStructCtor
local VKInstance = require 'vk.instance'
local sdl = require 'sdl'


ffi.cdef[[
char const * const * SDL_Vulkan_GetInstanceExtensions(uint32_t * count);
]]

local char_const_ptr = ffi.typeof'char const *'
local uint32_t_1 = ffi.typeof'uint32_t[1]'
local VkLayerProperties = ffi.typeof'VkLayerProperties'
local VkApplicationInfo = ffi.typeof'VkApplicationInfo'



-- TODO move to vk?
local function VK_MAKE_VERSION(major, minor, patch)
	return bit.bor(bit.lshift(major, 22), bit.lshift(minor, 12), patch)
end
local function VK_MAKE_API_VERSION(variant, major, minor, patch)
	return bit.bor(bit.lshift(variant, 29), bit.lshift(major, 22), bit.lshift(minor, 12), patch)
end
-- but why not just use bitfields? meh
local VK_API_VERISON_1_0 = VK_MAKE_API_VERSION(0, 1, 0, 0)


local VulkanInstance = class()

function VulkanInstance:init(common)
	local layerProps = vkGetVector(VkLayerProperties, vkassert, vk.vkEnumerateInstanceLayerProperties)
	print'vulkan layers:'
	for i=0,#layerProps-1 do
		print('',
			ffi.string(layerProps.v[i].layerName, vk.VK_MAX_EXTENSION_NAME_SIZE),
			ffi.string(layerProps.v[i].description, vk.VK_MAX_DESCRIPTION_SIZE)
		)
	end

	self.obj = VKInstance{
		applicationInfo = {
			pApplicationName = common.app.title,
			applicationVersion = VK_MAKE_API_VERSION(0, 1, 0, 0),
			pEngineName = 'no engine',
			engineVersion = VK_MAKE_API_VERSION(0, 1, 0, 0),
			apiVersion = VK_API_VERISON_1_0,
		},
		enabledLayers = table{
			common.enableValidationLayers and 'VK_LAYER_KHRONOS_validation' or nil,
		},
		enabledExtensions = self:getRequiredExtensions(common),
	}
end

function VulkanInstance:getRequiredExtensions(common)
	--[[ SDL2?
	local asserteq = require 'ext.assert'.eq
	local function sdlvksafe(f, ...)
		asserteq(sdl.SDL_TRUE, f(...))
	end
	local extensions = vkGetVector('char const *', sdlvksafe, sdl.SDL_Vulkan_GetInstanceExtensions, common.app.window)
	--]]
	-- [[ SDL3
	local extensions = table()
	do
		local count = uint32_t_1()
		local extstrs = assertne(sdl.SDL_Vulkan_GetInstanceExtensions(count), ffi.null)
		for i=0,count[0]-1 do
			extensions:insert(ffi.string(extstrs[i]))
		end
	end
	--]]

	print'vulkan extensions:'
	for _,s in ipairs(extensions) do
		print('', s)
	end

	if common.enableValidationLayers then
		extensions:insert'VK_EXT_debug_utils'
	end

	return extensions
end

return VulkanInstance
