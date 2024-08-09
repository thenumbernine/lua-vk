local table = require 'ext.table'
local vk = require 'vk'

local vkassert = require 'vk.util'.vkassert
local vkGetVector = require 'vk.util'.vkGetVector

local VKInstance = require 'vk.raii'{
	ctype = 'VkInstance',
	createType = 'VkInstanceCreateInfo',
	create = vk.vkCreateInstance,
	destroy = vk.vkDestroyInstance,
}

function VKInstance:getPhysDevs()
	local VKPhysDev = require 'vk.physdev'
	local physDevs = table()
	local physDevIDs = vkGetVector('VkPhysicalDevice', vkassert, vk.vkEnumeratePhysicalDevices, self.id)
	for i=0,#physDevIDs-1 do
		physDevs:insert(VKPhysDev(physDevIDs.v[i]))
	end
	return physDevs
end

return VKInstance
