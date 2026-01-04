local ffi = require 'ffi'
local assertindex = require 'ext.assert'.index
local vk = require 'vk'
local VKPhysDev = require 'vk.physdev'

local vkassert = require 'vk.util'.vkassert


local VkDevice_1 = ffi.typeof'VkDevice[1]'


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
	if VKPhysDev:isa(physDev) then physDev = physDev.id end

	local info = self:initFromArgs(args)
	local ptr = ffi.new(VkDevice_1)
	vkassert(vk.vkCreateDevice, physDev, info, nil, ptr)
	self.id = ptr[0]
end

function VKDevice:waitIdle()
	vkassert(vk.vkDeviceWaitIdle, self.id)
end

return VKDevice
