local assertindex = require 'ext.assert'.index
local vk = require 'ffi.req' 'vulkan'
local vkassert = require 'vk.util'.vkassert

local VKDevice = require 'vk.raii'{
	ctype = 'VkDevice',
	createType = 'VkDeviceCreateInfo',
	--create = vk.vkCreateDevice,	-- manually done
	destroy = vk.vkDestroyDevice,
}

function VKDevice:init(args)
	VKDevice.super.init(self)

	-- can I still pass args to ffi.new?  will it ignore extra fields?  seems alright ...
	local physDev = assertindex(args, 'physDev')

	local info = self:initFromArgs(args)
	vkassert(vk.vkCreateDevice, physDev, info, nil, self.gc.ptr)
	self.id = self.gc.ptr[0]
end

function VKDevice:waitIdle()
	vkassert(vk.vkDeviceWaitIdle, self.id)
end

return VKDevice
