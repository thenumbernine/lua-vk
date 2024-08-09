-- class wrapper (and maybe raii) for VkInstance
local ffi = require 'ffi'
local vk = require 'ffi.req' 'vulkan'
local GCWrapper = require 'ffi.gcwrapper.gcwrapper'

local vkassert = require 'vulkan.util'.vkassert

local VKInstance = GCWrapper{
	gctype = 'autorelease_vk_instance_ptr_t',
	ctype = 'VkInstance',
	release = function(ptr)
		vk.vkDestroyInstance(ptr[0], nil)
	end,
}:subclass()

function VKInstance:init(args)
	VKInstance.super.init(self)
	
	-- interpret info here
	local info
	if type(args) == 'cdata' then
		info = args
	else
		info = ffi.new('VkInstanceCreateInfo[1]', {args})	
		info[0].sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
	end

	vkassert(vk.vkCreateInstance, info, nil, self.gc.ptr)
	self.id = self.gc.ptr[0]
end

function VKInstance:destroy()
	vk.vkDestroyInstance(self.gc.ptr[0], nil)	-- or self.id ?  gc.ptr is only auto-cleared, id could be the old value ...
	self.gc.ptr[0] = nil
end

return VKInstance
