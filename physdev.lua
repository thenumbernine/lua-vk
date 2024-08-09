local class = require 'ext.class'
local vk = require 'vk'
local VKSurface = require 'vk.surface'

local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local vkGetVector = require 'vk.util'.vkGetVector

local VKPhysDev = class()

function VKPhysDev:init(id)
	self.id = assert(id)
end

function VKPhysDev:getProps()
	return vkGet('VkPhysicalDeviceProperties', nil, vk.vkGetPhysicalDeviceProperties, self.id)
end

function VKPhysDev:getFeatures()
	return vkGet('VkPhysicalDeviceFeatures', nil, vk.vkGetPhysicalDeviceFeatures, self.id)
end

function VKPhysDev:getQueueFamilyProperties()
	return vkGetVector('VkQueueFamilyProperties', nil, vk.vkGetPhysicalDeviceQueueFamilyProperties, self.id)
end

function VKPhysDev:getExtProps(layerName)
	return vkGetVector('VkExtensionProperties', vkassert, vk.vkEnumerateDeviceExtensionProperties, self.id, layerName)
end

function VKPhysDev:getFormatProps(format)
	return vkGet('VkFormatProperties', nil, vk.vkGetPhysicalDeviceFormatProperties, self.id, format)
end

function VKPhysDev:getMemProps()
	return vkGet('VkPhysicalDeviceMemoryProperties', nil, vk.vkGetPhysicalDeviceMemoryProperties, self.id)
end

function VKPhysDev:getSurfaceSupport(index, surface)
	if VKSurface:isa(surface) then surface = surface.id end
	return 0 ~= vkGet('VkBool32', vkassert, vk.vkGetPhysicalDeviceSurfaceSupportKHR, self.id, index, surface)
end

function VKPhysDev:getSurfaceCapabilities(surface)
	if VKSurface:isa(surface) then surface = surface.id end
	return vkGet('VkSurfaceCapabilitiesKHR', vkassert, vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR, self.id, surface)
end

function VKPhysDev:getSurfaceFormats(surface)
	if VKSurface:isa(surface) then surface = surface.id end
	return vkGetVector('VkSurfaceFormatKHR', vkassert, vk.vkGetPhysicalDeviceSurfaceFormatsKHR, self.id, surface)
end

function VKPhysDev:getSurfacePresentModes(surface)
	if VKSurface:isa(surface) then surface = surface.id end
	return vkGetVector('VkPresentModeKHR', vkassert, vk.vkGetPhysicalDeviceSurfacePresentModesKHR, self.id, surface)
end

return VKPhysDev 
