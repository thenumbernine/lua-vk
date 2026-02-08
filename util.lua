local ffi = require 'ffi'
local asserteq = require 'ext.assert'.eq
local assertindex = require 'ext.assert'.index
local vk = require 'vk'
local sdl = require 'sdl'
local vector = require 'stl.vector-lua'


local uint32_t_1 = ffi.typeof'uint32_t[1]'


local function countof(array)
	return ffi.sizeof(array) / (ffi.cast('uint8_t*', array+1) - ffi.cast('uint8_t*', array+0))
end

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
	if check then
		check(f, addlast(result, ...))
	else
		f(addlast(result, ...))
	end
	return result[0], result
end

local function vkGetVector(ctype, check, f, ...)
	local count = uint32_t_1()
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

local function getSTypeForCType(createType)
	createType = ffi.typeof(createType)
	local createTypeStr = tostring(createType)
	local createTypeName = createTypeStr:match'^ctype<(.*)>$'
		or error("failed to find ctype in createTypeStr "..tostring(createTypeStr))
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
	
	return assertindex(vk, enumName)
end

local function ident(...) return ... end

local function makeTableToArray(ctype, gen)
	ctype = ffi.typeof(ctype)
	local arrayType = ffi.typeof('$[?]', ctype)
	gen = gen or ident
	return function(v)
		local count = #v
		local arr = arrayType(count)
		for i=0,count-1 do
			arr[i] = gen(v[i+1])
		end
		return arr, count
	end
end

--[[
automatically set .sType based on the struct ctype name

also replace any tables keys with p / Count

replaceTableFields has:
	name = field name
	... etc

--]]
local function makeStructCtor(
	createType,
	replaceTableFields,
	skipSType
)
	createType = ffi.typeof(createType)
	local sType 
	if not skipSType then
		sType = getSTypeForCType(createType)
	end
	
	if replaceTableFields then
		for _,info in ipairs(replaceTableFields) do
			-- needs either .name and it to end it s or .ptrname and .countname...
			local fieldName = info.name
			info.type = info.type ~= nil and ffi.typeof(info.type) or nil

			if info.notarray then
				info.gen = info.gen or info.type
			else
				info.gen = info.gen or ident
				-- for handling arrays
				local baseName = fieldName and fieldName:match'^(.*)s$'
				info.ptrname = info.ptrname or 'p'..fieldName:sub(1,1):upper()..fieldName:sub(2)
				info.countname = info.countname or baseName..'Count'
				info.arrayType = ffi.typeof('$[?]', info.type)
				info.tableToArray = makeTableToArray(info.type, info.gen)
			end
		end
	end

	return function(args)
		args = args or {}
		if not skipSType then
			args.sType = sType
		end
		if replaceTableFields then
			for _,info in ipairs(replaceTableFields) do
				local fieldName = info.name
				local gen = info.gen
				local v = args[fieldName]
				if v ~= nil then
					if info.notarray then
						args[fieldName] = nil
						args[info.ptrname] = gen(v)
					else
						local fieldType = info.type
						local tp = type(v)
						if tp == 'table' then
							args[fieldName], args[info.ptrname], args[info.countname] = nil, info.tableToArray(v)
						elseif tp == 'cdata' 
						and ffi.typeof(v) == info.arrayType
						then
							args[fieldName], args[info.ptrname], args[info.countname] = nil, v, countof(v)
						else
							error('idk how to handle type '..tp)
						end
					end
					if info.also then
						info.also(args, v)
					end
				end
			end
		end

		return createType(args)
	end
end

-- expects cl to have .createType and optional .sType
local function addInitFromArgs(cl)
	local createType = assertindex(cl, 'createType')
	createType = ffi.typeof(createType)

	--[[ require manually specifying sType
	local sType = assertindex(cl, 'sType')
	--]]
	-- [[ override with automatic deduction (since vulkan has such a clean API)
	local sType = cl.sType or getSTypeForCType(createType)
	--]]

	-- phasing this out in favor of makeStructCtor?
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

local function vkResult(result, name)
	if result == vk.VK_SUCCESS then
		return true, nil, result
	else
		local strresult = tostring(result)
		return false, name and (name..': '..strresult) or strresult, result
	end
end

return {
	countof = countof,
	vkassert = vkassert,
	vkGet = vkGet,
	vkResult = vkResult,
	vkGetVector = vkGetVector,
	addInitFromArgs = addInitFromArgs,
	makeStructCtor = makeStructCtor,
	makeTableToArray = makeTableToArray,
}
