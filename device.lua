local ffi = require 'ffi'
local assertindex = require 'ext.assert'.index
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local VKPhysDev = require 'vk.physdev'


local VkDevice = ffi.typeof'VkDevice'
local VkDeviceCreateInfo = ffi.typeof'VkDeviceCreateInfo'


local VKDevice = require 'vk.raii'{
	ctype = VkDevice,
	createType = VkDeviceCreateInfo,
	--create = vk.vkCreateDevice,	-- manually done
	destroy = vk.vkDestroyDevice,
}

function VKDevice:init(args)
	-- can I still pass args to ffi.new?  will it ignore extra fields?  seems alright ...
	local physDev = assertindex(args, 'physDev')
	if VKPhysDev:isa(physDev) then physDev = physDev.id end
	self.id = vkGet(
		VkDevice,
		vkassert,
		vk.vkCreateDevice,
		physDev,
		self:initFromArgs(args),
		nil
	)
end

function VKDevice:waitIdle()
	vkassert(vk.vkDeviceWaitIdle, self.id)
end

return VKDevice
