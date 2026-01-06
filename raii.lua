-- class wrapper (and maybe raii) for VkInstance
require 'ext.gc'	-- make sure luajit can __gc lua-tables
local ffi = require 'ffi'
local class = require 'ext.class'
local assertindex = require 'ext.assert'.index
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet


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
	ctype = ffi.typeof(ctype)
	
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
			self.createInfo = self:initFromArgs(args)
			self.id = vkGet(ctype, vkassert, create, self.createInfo, nil)
			self.createInfo = nil
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
