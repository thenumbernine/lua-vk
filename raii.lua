-- class wrapper (and maybe raii) for VkInstance
require 'ext.gc'	-- make sure luajit can __gc lua-tables
local ffi = require 'ffi'
local vk = require 'vk'
local class = require 'ext.class'
local assertindex = require 'ext.assert'.index

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
	local ctype_1 = ffi.typeof('$[1]', ctype)
	
	-- create might ask for extra arguments.
	-- rather than provide how to describe them here, I'll let each subclass perform the call.
	--local create = assertindex(args, 'create')
	--local createType = assertindex(args, 'createType')
	local create = args.create
	
	-- I think all destroy functions have just one arg + allocator ...
	local destroy = assertindex(args, 'destroy')

	local cl = class()

	cl.createType = args.createType
	cl.sType = args.sType
	require 'vk.util'.addInitFromArgs(cl)

	if create then
		assert(cl.createType)
		function cl:init(args)
			cl.super.init(self)

			local info = self:initFromArgs(args)
			local ptr = ffi.new(ctype_1)
			vkassert(create, info, nil, ptr)
			self.id = ptr[0]
		end
	end

	function cl:destroy()
		if self.id == nil then return end
		destroy(self.id, nil)	-- or self.id ?  gc.ptr is only auto-cleared, id could be the old value ...
		self.id = nil
	end

	cl.__gc = cl.destroy

	return cl
end
