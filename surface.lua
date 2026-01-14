require 'ext.gc'	-- make sure luajit can __gc lua-tables
local ffi = require 'ffi'
local class = require 'ext.class'
local assertindex = require 'ext.assert'.index
local assertne = require 'ext.assert'.ne
local sdl = require 'sdl'
local sdlAssert = require 'sdl.assert'.assert
local vk = require 'vk'
local vkGet = require 'vk.util'.vkGet
local VKInstance = require 'vk.instance'

-- TODO put this in sdl/ffi/sdl3.lua ...
ffi.cdef[[
bool SDL_Vulkan_CreateSurface(
	SDL_Window *window,
	VkInstance instance,
	const struct VkAllocationCallbacks *allocator,
	VkSurfaceKHR *surface);
]]


local VkSurfaceKHR = ffi.typeof'VkSurfaceKHR'
local VkSurfaceKHR_1 = ffi.typeof'VkSurfaceKHR[1]'


local VKSurface = class()

function VKSurface:init(args)
	local window = assertindex(args, 'window')
	local instance = assertindex(args, 'instance')
	if VKInstance:isa(instance) then instance = assertindex(instance, 'id') end
	self.instance = instance

--[[ check() has the responsibility of passing the args to the function, which sdlAssert doesn't do
	self.id = vkGet(VkSurfaceKHR, sdlAssert, sdl.SDL_Vulkan_CreateSurface, window, instance, nil)
--]]
-- [[
	local ptr = VkSurfaceKHR_1()
	sdlAssert(sdl.SDL_Vulkan_CreateSurface(window, instance, nil, ptr), 'SDL_Vulkan_CreateSurface')
	self.id = ptr[0]
--]]
end

function VKSurface:destroy()
	if self.instance == nil and self.id == nil then return end
	assertne(self.instance, nil)
	assertne(self.id, nil)
	vk.vkDestroySurfaceKHR(self.instance, self.id, nil)
	-- what about SDL_Vulkan_DestroySurface?  same? both?
	self.id = nil
	self.instance = nil
end

VKSurface.__gc = VKSurface.destroy

return VKSurface
