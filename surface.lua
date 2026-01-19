require 'ext.gc'	-- make sure luajit can __gc lua-tables
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local sdl = require 'sdl'
local sdlAssert = require 'sdl.assert'.assert
local vk = require 'vk'
local vkGet = require 'vk.util'.vkGet

-- TODO put this in sdl/ffi/sdl3.lua ...
ffi.cdef[[
bool SDL_Vulkan_CreateSurface(
	SDL_Window *window,
	VkInstance instance,
	const struct VkAllocationCallbacks *allocator,
	VkSurfaceKHR *surface);
]]


local VkSurfaceKHR_1 = ffi.typeof'VkSurfaceKHR[1]'


local VKSurface = class()

function VKSurface:init(args)
	local window = assert.index(args, 'window')
	local instance = assert.index(args, 'instance')
	self.instance = instance

--[[ check() has the responsibility of passing the args to the function, which sdlAssert doesn't do
	local VkSurfaceKHR = ffi.typeof'VkSurfaceKHR'
	self.id = vkGet(VkSurfaceKHR, sdlAssert, sdl.SDL_Vulkan_CreateSurface, window, instance, nil)
--]]
-- [[
	self.idptr = VkSurfaceKHR_1()
	sdlAssert(sdl.SDL_Vulkan_CreateSurface(window, instance, nil, self.idptr), 'SDL_Vulkan_CreateSurface')
	self.id = self.idptr[0]
--]]
end

function VKSurface:destroy()
	if self.id then 
		vk.vkDestroySurfaceKHR(self.instance, self.id, nil)
		-- what about SDL_Vulkan_DestroySurface?  same? both?
	end
	self.id = nil
end

function VKSurface:__gc()
	return self:destroy()
end

return VKSurface
