local ffi = require 'ffi'
local asserteq = require 'ext.assert'.eq
local assertindex = require 'ext.assert'.index
local vk = require 'vk'
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

-- expects cl to have .createType and optional .sType
local function addInitFromArgs(cl)
	local createType = assertindex(cl, 'createType')
	--[[ require manually specifying sType
	local sType = assertindex(cl, 'sType')
	--]]
	-- [[ override with automatic deduction (since vulkan has such a clean API)
	local sType = cl.sType
	if not sType and createType then
		local structBaseName = createType:match'^Vk(.*)$'
		local enumName = ''
		local lastWasUpper
		for i=1,#structBaseName do
			local ch = structBaseName:sub(i,i)
			local uch = ch:upper()
			local isUpper = ch == uch
			if isUpper
			and not lastWasUpper
			then
				enumName = enumName .. '_'
			end
			enumName = enumName .. uch
			lastWasUpper = isUpper
		end
		
		enumName = 'VK_STRUCTURE_TYPE' .. enumName
		sType = assertindex(vk, enumName)
	end
	--]]

	function cl:initFromArgs(args)
		if type(args) == 'cdata' then
			return args
		else
			local info = ffi.new(createType..'[1]', {args})	
			info[0].sType = sType
			return info
		end
	end
end

return {
	vkassert = vkassert,
	sdlvksafe = sdlvksafe,
	vkGet = vkGet,
	vkGetVector = vkGetVector,
	addInitFromArgs = addInitFromArgs,
}
