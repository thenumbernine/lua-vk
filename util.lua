local asserteq = require 'ext.assert'.eq
local vk = require 'ffi.req' 'vulkan'
local sdl = require 'sdl'

local function vkassert(f, ...)
	local res = f(...)
	if res ~= vk.VK_SUCCESS then
		error('failed with error '..tostring(res))
	end
end

local function sdlvksafe(f, ...)
	asserteq(sdl.SDL_TRUE, f(...))
end

return {
	vkassert = vkassert,
	sdlvksafe = sdlvksafe,
}
