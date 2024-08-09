-- class wrapper (and maybe raii) for VkInstance
local ffi = require 'ffi'
local vk = require 'vk'
local assertindex = require 'ext.assert'.index
local GCWrapper = require 'ffi.gcwrapper.gcwrapper'

local vkassert = require 'vk.util'.vkassert

--[[
args:
	ctype = ctype of vk handle
	destroy = called to deallocate upon gc
	create = (optional) create function
	createType = (optional) struct for create 
	sType = (optional) signature of create struct
--]]
return function(args)
	local ctype = assertindex(args, 'ctype')
	
	-- create might ask for extra arguments.
	-- rather than provide how to describe them here, I'll let each subclass perform the call.
	--local create = assertindex(args, 'create')
	--local createType = assertindex(args, 'createType')
	local create = args.create
	
	-- I think all destroy functions have just one arg + allocator ...
	local destroy = assertindex(args, 'destroy')

	local cl = GCWrapper{
		gctype = 'autorelease_'..ctype..'_ptr_t',
		ctype = ctype,
		release = function(ptr)
print('destroying '..tostring(ctype)..' '..tostring(ptr[0]))
			destroy(ptr[0], nil)
		end,
	}:subclass()
	
	cl.createType = args.createType
	cl.sType = args.sType
	require 'vk.util'.addInitFromArgs(cl)

	if create then
		assert(cl.createType)
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
