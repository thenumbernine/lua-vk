local ffi = require 'ffi'
local GCWrapper = require 'ffi.gcwrapper.gcwrapper'
local assertindex = require 'ext.assert'.index
local assertne = require 'ext.assert'.ne
local sdl = require 'sdl'
local vk = require 'vk'
local VKInstance = require 'vk.instance'

local sdlvksafe = require 'vk.util'.sdlvksafe

-- TODO put these in SDL2 ... they don't immediately #include
ffi.cdef[[
SDL_bool SDL_Vulkan_CreateSurface(
	SDL_Window *window,
	VkInstance instance,
	VkSurfaceKHR* surface);
]]

local ctype = 'VkSurfaceKHR'

-- same kind of dtor gc as swapchain
local dtortype = 'autorelease_'..ctype..'_dtor_t'
require 'struct'{
	name = dtortype,
	fields = {
		{name='surface', type=ctype..'[1]'},
		{name='instance', type='VkInstance'},
	},
}

local VKSurface = GCWrapper{
	gctype = 'autorelease_'..ctype..'_ptr_t',
	ctype = dtortype,
	release = function(ptr)
		if ptr[0].instance == nil and ptr[0].surface[0] == nil then return end
		assertne(ptr[0].instance, nil)
		assertne(ptr[0].surface[0], nil)
		vk.vkDestroySurfaceKHR(ptr[0].instance, ptr[0].surface[0], nil)
	end,
}:subclass()

function VKSurface:init(args)
	local window = assertindex(args, 'window')

	local instance = assertindex(args, 'instance')
	if VKInstance:isa(instance) then instance = instance.id end
	
	local dtorinit = ffi.new(dtortype)
	dtorinit.instance = instance

	sdlvksafe(sdl.SDL_Vulkan_CreateSurface, window, instance, dtorinit.surface)
	
	VKSurface.super.init(self, dtorinit)

	self.id = self.gc.ptr[0].surface[0]
end

function VKSurface:destroy()
	local ptr = self.gc.ptr
	if ptr[0].instance == nil and ptr[0].surface[0] == nil then return end
	assertne(ptr[0].instance, nil)
	assertne(ptr[0].surface[0], nil)
	vk.vkDestroySurfaceKHR(ptr[0].instance, ptr[0].surface[0], nil)
	ptr[0].surface[0] = nil
	ptr[0].instance = nil
end

return VKSurface
