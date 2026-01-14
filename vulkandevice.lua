-- helper not wrapper
local ffi = require 'ffi'
local class = require 'ext.class'
local assertindex = require 'ext.assert'.index
local vector = require 'ffi.cpp.vector-lua'
local vk = require 'vk'
local defs = require 'vk.defs'
local VKDevice = require 'vk.device'


local char_const_ptr = ffi.typeof'char const *'
local float_1 = ffi.typeof'float[1]'
local VkDeviceQueueCreateInfo = ffi.typeof'VkDeviceQueueCreateInfo'
local VkPhysicalDeviceFeatures_1 = ffi.typeof'VkPhysicalDeviceFeatures[1]'


local VulkanDevice = class()

function VulkanDevice:init(physDev, deviceExtensions, enableValidationLayers, indices)
	self.queuePriorities = float_1()
	self.queuePriorities[0] = 1
	self.queueCreateInfos = vector(VkDeviceQueueCreateInfo)
	for queueFamily in pairs{
		[indices.graphicsFamily] = true,
		[indices.presentFamily] = true,
	} do
		self.queueCreateInfos:emplace_back()[0] = VkDeviceQueueCreateInfo{
			sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
			queueFamilyIndex = queueFamily,
			queueCount = 1,
			pQueuePriorities = self.queuePriorities,
		}
	end

	self.deviceFeatures = VkPhysicalDeviceFeatures_1()
	self.deviceFeatures[0].samplerAnisotropy = vk.VK_TRUE

	self.thisValidationLayers = vector(char_const_ptr)
	if enableValidationLayers then
		self.thisValidationLayers:emplace_back()[0] = assertindex(defs, 'validationLayer')
	end

	self.obj = VKDevice{
		-- create extra args:
		physDev = physDev,
		-- info args:
		queueCreateInfoCount = #self.queueCreateInfos,
		pQueueCreateInfos = self.queueCreateInfos.v,
		enabledLayerCount = #self.thisValidationLayers,
		ppEnabledLayerNames = self.thisValidationLayers.v,
		enabledExtensionCount = #deviceExtensions,
		ppEnabledExtensionNames = deviceExtensions.v,
		pEnabledFeatures = self.deviceFeatures,
	}
	
	self.thisValidationLayers = nil
	self.deviceFeatures = nil
	self.queueCreateInfos = nil
	self.queuePriorities = nil
end

return VulkanDevice
