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
	self.queuePriorities = vector(float, {1})
	self.queueCreateInfos = vector(VkDeviceQueueCreateInfo)
	for queueFamily in pairs{
		[indices.graphicsFamily] = true,
		[indices.presentFamily] = true,
	} do
		self.queueCreateInfos:emplace_back()[0] = VkDeviceQueueCreateInfo{
			sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
			queueFamilyIndex = queueFamily,
			queueCount = #self.queuePriorities,
			pQueuePriorities = self.queuePriorities.v,
		}
	end

	self.deviceFeatures = ffi.new(VkPhysicalDeviceFeatures_1, {{
		samplerAnisotropy = vk.VK_TRUE,
	}})

	self.thisValidationLayers = vector(char_const_ptr)
	if enableValidationLayers then
		self.thisValidationLayers.emplace_back()[0] = vk.validationLayer
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
