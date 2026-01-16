local ffi = require 'ffi'
local asserteq = require 'ext.assert'.eq
local assertindex = require 'ext.assert'.index
local vk = require 'vk'
local sdl = require 'sdl'
local vector = require 'ffi.cpp.vector-lua'


local uint32_t_1 = ffi.typeof'uint32_t[1]'


local function vkassert(f, ...)
	local res = f(...)
	if res ~= vk.VK_SUCCESS then
		error('failed with error '..tostring(res))
	end
end

local function addlast(last, ...)
	if select('#', ...) == 0 then
		return last
	else
		return select(1, ...), addlast(last, select(2, ...))
	end
end

local function vkGet(ctype, check, f, ...)
	ctype = ffi.typeof(ctype)
	local resultType = ffi.typeof('$[1]', ctype)
	local result = resultType()
_G.vkGetRetain = result
	if check then
		check(f, addlast(result, ...))
	else
		f(addlast(result, ...))
	end
	return result[0]
end

local function vkGetVector(ctype, check, f, ...)
	local count = uint32_t_1()
_G.vkGetVectorRetainCount = count
	if check then
		check(f, addlast(nil, addlast(count, ...)))
	else
		f(addlast(nil, addlast(count, ...)))
	end
	local vec = vector(ctype)
_G.vkGetVectorRetainVec = vec
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
	createType = ffi.typeof(createType)

	--[[ require manually specifying sType
	local sType = assertindex(cl, 'sType')
	--]]
	-- [[ override with automatic deduction (since vulkan has such a clean API)
	local sType = cl.sType
	if not sType then
		local createTypeStr = tostring(createType)
		local createTypeName = createTypeStr:match'^ctype<(.*)>$'
		createTypeName = createTypeName:match'^struct (.*)$' or createTypeName -- work around typedefs
		local structBaseName = createTypeName:match'^Vk(.*)$' or error("couldn't find Vk(.*) in "..tostring(createTypeName))
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
			args.sType = sType
			self.initArgs = createType(args)
			return self.initArgs
		end
	end
end

return {
	vkassert = vkassert,
	vkGet = vkGet,
	vkGetVector = vkGetVector,
	addInitFromArgs = addInitFromArgs,
}
