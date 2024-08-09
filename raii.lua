-- class wrapper (and maybe raii) for VkInstance
local ffi = require 'ffi'
local vk = require 'ffi.req' 'vulkan'
local assertindex = require 'ext.assert'.index
local GCWrapper = require 'ffi.gcwrapper.gcwrapper'

local vkassert = require 'vk.util'.vkassert

return function(args)
	local ctype = assertindex(args, 'ctype')
	
	-- create might ask for extra arguments.
	-- rather than provide how to describe them here, I'll let each subclass perform the call.
	--local create = assertindex(args, 'create')
	--local createType = assertindex(args, 'createType')
	local create = args.create
	local createType = args.createType
	
	-- I think all destroy functions have just one arg + allocator ...
	local destroy = assertindex(args, 'destroy')

	--[[ require manually specifying sType
	local sType = assertindex(args, 'sType')
	--]]
	-- [[ override with automatic deduction (since vulkan has such a clean API)
	local sType = args.sType
	if not sType and createType then
		sType = assertindex(vk, 'VK_STRUCTURE_TYPE'..createType:match'^Vk(.*)$':gsub('.', function(ch)
			if ch:match'[A-Z]' then
				return '_'..ch
			else
				return ch:upper()
			end
		end))
	end
	--]]

	local cl = GCWrapper{
		gctype = 'autorelease_'..ctype..'_ptr_t',
		ctype = ctype,
		release = function(ptr)
print('destroying '..tostring(ctype)..' '..tostring(ptr[0]))
			destroy(ptr[0], nil)
		end,
	}:subclass()

	function cl:initFromArgs(args)
		if type(args) == 'cdata' then
			return args
		else
			local info = ffi.new(createType..'[1]', {args})	
			info[0].sType = sType
			return info
		end
	end

	if create then
		assert(createType)
		function cl:init(args)
			cl.super.init(self)

			local info = self:initFromArgs(args)
			vkassert(create, info, nil, self.gc.ptr)
			self.id = self.gc.ptr[0]
		end
	end

	function cl:destroy()
		destroy(self.gc.ptr[0], nil)	-- or self.id ?  gc.ptr is only auto-cleared, id could be the old value ...
		self.gc.ptr[0] = nil
	end

	return cl
end
