local ffi = require 'ffi'
local asserteq = require 'ext.assert'.eq
local vk = require 'ffi.req' 'vulkan'
local sdl = require 'sdl'
local vector = require 'ffi.cpp.vector-lua'

local function vkassert(f, ...)
	local res = f(...)
	if res ~= vk.VK_SUCCESS then
		error('failed with error '..tostring(res))
	end
end

local function sdlvksafe(f, ...)
	asserteq(sdl.SDL_TRUE, f(...))
end

local function addlast(last, ...)
	if select('#', ...) == 0 then
		return last
	else
		return select(1, ...), addlast(last, select(2, ...))
	end
end

local function vkGet(ctype, check, f, ...)
	local result = ffi.new(ctype..'[1]')
	if check then
		check(f, addlast(result, ...))
	else
		f(addlast(result, ...))
	end
	return result[0]
end

local function vkGetVector(ctype, check, f, ...)
	local count = ffi.new'uint32_t[1]'
	if check then
		check(f, addlast(nil, addlast(count, ...)))
	else
		f(addlast(nil, addlast(count, ...)))
	end
	local vec = vector(ctype)
	vec:resize(count[0])
	if check then
		check(f, addlast(vec.v, addlast(count, ...)))
	else
		f(addlast(vec.v, addlast(count, ...)))
	end
	return vec
end

return {
	vkassert = vkassert,
	sdlvksafe = sdlvksafe,
	vkGet = vkGet,
	vkGetVector = vkGetVector,
}
