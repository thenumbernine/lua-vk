local class = require 'ext.class'
local vk = require 'vk'

local vkGet = require 'vk.util'.vkGet

local VKPhysDev = class()

function VKPhysDev:init(id)
	self.id = assert(id)
end

function VKPhysDev:getProps()
	return vkGet('VkPhysicalDeviceProperties', nil, vk.vkGetPhysicalDeviceProperties, self.id)
end

return VKPhysDev 
