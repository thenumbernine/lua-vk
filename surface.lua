local ffi = require 'ffi'
local assertindex = require 'ext.assert'.index
local sdl = require 'sdl'
local GCWrapper = require 'ffi.gcwrapper.gcwrapper'
local VKInstance = require 'vk.instance'
local sdlvksafe = require 'vk.util'.sdlvksafe

-- TODO put these in SDL2 ... they don't immediately #include
ffi.cdef[[
SDL_bool SDL_Vulkan_CreateSurface(
	SDL_Window *window,
	VkInstance instance,
	VkSurfaceKHR* surface);
]]

--[[ here's another atypical destroy ... so I can't use vk.raii
local VKSurface = GCWrapper{
	gctype = 'autorelease_VkSurfaceKHR_ptr_t',
	ctype = 'VkSurfaceKHR',
	release = function(ptr)
		vk.vkDestroySurfaceKHR(ptr[0].instance, ptr[0].surface)
	end,
}
--]]
-- but in fact neither vulkan_raii nor the demo calls vkDestroySurface ...
local VKSurface = require 'ext.class'()

function VKSurface:init(args)
	local window = assertindex(args, 'window')

	local instance = assertindex(args, 'instance')
	if VKInstance:isa(instance) then instance = instance.id end
	
	-- for dtor convenience, capture the VkInstance cdata
	-- for oop convenience until then, capture the obj ...
	--self.instance = instance

	self.gc = ffi.new'VkSurfaceKHR[1]'
	sdlvksafe(sdl.SDL_Vulkan_CreateSurface, window, instance, self.gc)
	self.id = self.gc[0]
end

return VKSurface
