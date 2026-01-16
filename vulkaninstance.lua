-- helper, not wrapper
local ffi = require 'ffi'
local class = require 'ext.class'
local assertne = require 'ext.assert'.ne
local vector = require 'ffi.cpp.vector-lua'
local vk = require 'vk'
local defs = require 'vk.defs'
local vkassert = require 'vk.util'.vkassert
local vkGetVector = require 'vk.util'.vkGetVector
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


defs.engineName ="No Engine"


local VulkanInstance = class()

function VulkanInstance:init(common)
	local app = common.app
	local enableValidationLayers = common.enableValidationLayers

	local layerProps = vkGetVector(VkLayerProperties, vkassert, vk.vkEnumerateInstanceLayerProperties)
	print'vulkan layers:'
	for i=0,#layerProps-1 do
		print('',
			ffi.string(layerProps.v[i].layerName, vk.VK_MAX_EXTENSION_NAME_SIZE),
			ffi.string(layerProps.v[i].description, vk.VK_MAX_DESCRIPTION_SIZE)
		)
	end

	-- how to prevent gc until a variable is done?
	local info = VkApplicationInfo()
	info.sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO
	info.pApplicationName = app.title
	info.applicationVersion = VK_MAKE_API_VERSION(0, 1, 0, 0)
	info.pEngineName = defs.engineName
	info.engineVersion = VK_MAKE_API_VERSION(0, 1, 0, 0)
	info.apiVersion = VK_API_VERISON_1_0

	local layerNames = vector(char_const_ptr)
	if enableValidationLayers then
		layerNames:emplace_back()[0] = defs.VK_LAYER_KHRONOS_VALIDATION_NAME
	end

	local extensions = self:getRequiredExtensions(common)

	self.obj = VKInstance{
		pApplicationInfo = info,
		enabledLayerCount = #layerNames,
		ppEnabledLayerNames = layerNames.v,
		enabledExtensionCount = #extensions,
		ppEnabledExtensionNames = extensions.v,
	}
end

function VulkanInstance:getRequiredExtensions(common)
	local app = common.app
	local enableValidationLayers = common.enableValidationLayers

	--[[ SDL2?
	local asserteq = require 'ext.assert'.eq
	local function sdlvksafe(f, ...)
		asserteq(sdl.SDL_TRUE, f(...))
	end
	local extensions = vkGetVector('char const *', sdlvksafe, sdl.SDL_Vulkan_GetInstanceExtensions, app.window)
	--]]
	-- [[ SDL3
	local extensions = vector(char_const_ptr)
	do
		local count = uint32_t_1()
		local extstrs = assertne(sdl.SDL_Vulkan_GetInstanceExtensions(count), ffi.null)
		for i=0,count[0]-1 do
			extensions:push_back(extstrs[i])
		end
	end
	--]]

	print'vulkan extensions:'
	for i=0,#extensions-1 do
		print('', ffi.string(extensions.v[i]))
	end

	if enableValidationLayers then
		extensions:emplace_back()[0] = defs.VK_EXT_DEBUG_UTILS_EXTENSION_NAME
	end

	return extensions
end

return VulkanInstance
