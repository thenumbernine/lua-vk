-- helper not wrapper
local ffi = require 'ffi'
local class = require 'ext.class'
local vector = require 'ffi.cpp.vector-lua'
local vk = require 'vk'
local VKDevice = require 'vk.device'


vk.validationLayer = 'VK_LAYER_KHRONOS_validation'	-- TODO vector?


local char_const_ptr = ffi.typeof'char const *'
local float = ffi.typeof'float'
local VkDeviceQueueCreateInfo = ffi.typeof'VkDeviceQueueCreateInfo'
local VkPhysicalDeviceFeatures_1 = ffi.typeof'VkPhysicalDeviceFeatures[1]'


local VulkanDevice = class()

function VulkanDevice:init(physDev, deviceExtensions, enableValidationLayers, indices)
	local queuePriorities = vector(float)
	queuePriorities:emplace_back()[0] = 1
	local queueCreateInfos = vector(VkDeviceQueueCreateInfo)
	for queueFamily in pairs{
		[indices.graphicsFamily] = true,
		[indices.presentFamily] = true,
	} do
		local info = queueCreateInfos:emplace_back()
		info[0].sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
		info[0].queueFamilyIndex = queueFamily
		info[0].queueCount = #queuePriorities
		info[0].pQueuePriorities = queuePriorities.v
	end

	local deviceFeatures = ffi.new(VkPhysicalDeviceFeatures_1)
	deviceFeatures[0].samplerAnisotropy = vk.VK_TRUE

	local thisValidationLayers = vector(char_const_ptr)
	if enableValidationLayers then
		thisValidationLayers.emplace_back()[0] = validationLayer	-- TODO vector copy?
	end

	self.obj = VKDevice{
		-- create extra args:
		physDev = physDev,
		-- info args:
		queueCreateInfoCount = #queueCreateInfos,
		pQueueCreateInfos = queueCreateInfos.v,
		enabledLayerCount = #thisValidationLayers,
		ppEnabledLayerNames = thisValidationLayers.v,
		enabledExtensionCount = #deviceExtensions,
		ppEnabledExtensionNames = deviceExtensions.v,
		pEnabledFeatures = deviceFeatures,
	}
end

return VulkanDevice
