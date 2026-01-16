-- helper not wrapper
local ffi = require 'ffi'
local class = require 'ext.class'
local assertindex = require 'ext.assert'.index
local vector = require 'ffi.cpp.vector-lua'
local vk = require 'vk'
local defs = require 'vk.defs'
local makeStructCtor = require 'vk.util'.makeStructCtor
local VKDevice = require 'vk.device'


local char_const_ptr = ffi.typeof'char const *'
local float_1 = ffi.typeof'float[1]'
local VkDeviceQueueCreateInfo = ffi.typeof'VkDeviceQueueCreateInfo'
local VkPhysicalDeviceFeatures = ffi.typeof'VkPhysicalDeviceFeatures'


local makeVkDeviceQueueCreateInfo = makeStructCtor'VkDeviceQueueCreateInfo'


local VulkanDevice = class()

function VulkanDevice:init(physDev, deviceExtensions, enableValidationLayers, indices)
	local queuePriorities = float_1(1)
	local queueCreateInfos = vector(VkDeviceQueueCreateInfo)
	for queueFamily in pairs{
		[indices.graphicsFamily] = true,
		[indices.presentFamily] = true,
	} do
		queueCreateInfos:emplace_back()[0] = makeVkDeviceQueueCreateInfo{
			queueFamilyIndex = queueFamily,
			queueCount = 1,
			pQueuePriorities = queuePriorities,
		}
	end

	local deviceFeatures = VkPhysicalDeviceFeatures()
	deviceFeatures.samplerAnisotropy = vk.VK_TRUE

	local thisValidationLayers = vector(char_const_ptr)
	if enableValidationLayers then
		thisValidationLayers:emplace_back()[0] = assertindex(defs, 'validationLayer')
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
