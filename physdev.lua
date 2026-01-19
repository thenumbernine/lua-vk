local ffi = require 'ffi'
local class = require 'ext.class'
local vk = require 'vk'
local VKSurface = require 'vk.surface'

local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local vkGetVector = require 'vk.util'.vkGetVector


local VkPhysicalDeviceProperties = ffi.typeof'VkPhysicalDeviceProperties'
local VkPhysicalDeviceFeatures = ffi.typeof'VkPhysicalDeviceFeatures'
local VkQueueFamilyProperties = ffi.typeof'VkQueueFamilyProperties'
local VkExtensionProperties = ffi.typeof'VkExtensionProperties'
local VkFormatProperties = ffi.typeof'VkFormatProperties'
local VkPhysicalDeviceMemoryProperties = ffi.typeof'VkPhysicalDeviceMemoryProperties'
local VkBool32 = ffi.typeof'VkBool32'
local VkSurfaceCapabilitiesKHR = ffi.typeof'VkSurfaceCapabilitiesKHR'
local VkSurfaceFormatKHR = ffi.typeof'VkSurfaceFormatKHR'
local VkPresentModeKHR = ffi.typeof'VkPresentModeKHR'


local VKPhysDev = class()

function VKPhysDev:init(id)
	self.id = assert(id)
end

function VKPhysDev:getProps()
	return vkGet(VkPhysicalDeviceProperties, nil, vk.vkGetPhysicalDeviceProperties, self.id)
end

function VKPhysDev:getFeatures()
	return vkGet(VkPhysicalDeviceFeatures, nil, vk.vkGetPhysicalDeviceFeatures, self.id)
end

function VKPhysDev:getQueueFamilyProperties()
	return vkGetVector(VkQueueFamilyProperties, nil, vk.vkGetPhysicalDeviceQueueFamilyProperties, self.id)
end

function VKPhysDev:getExtProps(layerName)
	return vkGetVector(VkExtensionProperties, vkassert, vk.vkEnumerateDeviceExtensionProperties, self.id, layerName)
end

function VKPhysDev:getFormatProps(format)
	return vkGet(VkFormatProperties, nil, vk.vkGetPhysicalDeviceFormatProperties, self.id, format)
end

function VKPhysDev:getMemProps()
	return vkGet(VkPhysicalDeviceMemoryProperties, nil, vk.vkGetPhysicalDeviceMemoryProperties, self.id)
end

function VKPhysDev:getSurfaceSupport(index, surface)
	if VKSurface:isa(surface) then surface = surface.id end
	-- [[
	return 0 ~= vkGet(VkBool32, vkassert, vk.vkGetPhysicalDeviceSurfaceSupportKHR, self.id, index, surface)
	--]]
	--[[ debugging
	local result = VkBool32_1()
	vk.vkGetPhysicalDeviceSurfaceSupportKHR(self.id, index, surface, result)
	print('vkGetPhysicalDeviceSurfaceSupportKHR(', self.id, index, surface,') result', result[0])
	return result[0] ~= 0
	--]]
end

function VKPhysDev:getSurfaceCapabilities(surface)
	if VKSurface:isa(surface) then surface = surface.id end
	return vkGet(VkSurfaceCapabilitiesKHR, vkassert, vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR, self.id, surface)
end

function VKPhysDev:getSurfaceFormats(surface)
	if VKSurface:isa(surface) then surface = surface.id end
	return vkGetVector(VkSurfaceFormatKHR, vkassert, vk.vkGetPhysicalDeviceSurfaceFormatsKHR, self.id, surface)
end

function VKPhysDev:getSurfacePresentModes(surface)
	if VKSurface:isa(surface) then surface = surface.id end
	return vkGetVector(VkPresentModeKHR, vkassert, vk.vkGetPhysicalDeviceSurfacePresentModesKHR, self.id, surface)
end

-- helper functions:

function VKPhysDev:makeDevice(args, ...)
	args.physDev = self.id
	local VKDevice = require 'vk.device'
	return VKDevice(args, ...)
end

function VKPhysDev:findDepthFormat()
	return self:findSupportedFormat(
		{
			vk.VK_FORMAT_D32_SFLOAT,
			vk.VK_FORMAT_D32_SFLOAT_S8_UINT,
			vk.VK_FORMAT_D24_UNORM_S8_UINT,
		},
		vk.VK_IMAGE_TILING_OPTIMAL,
		vk.VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT
	)
end

function VKPhysDev:findSupportedFormat(candidates, tiling, features)
	for _,format in ipairs(candidates) do
		local props = self:getFormatProps(format)
		if tiling == vk.VK_IMAGE_TILING_LINEAR
		and bit.band(props.linearTilingFeatures, features) == features
		then
			return format
		elseif tiling == vk.VK_IMAGE_TILING_OPTIMAL
		and bit.band(props.optimalTilingFeatures, features) == features
		then
			return format
		end
	end
	error "failed to find supported format!"
end

local sampleCountBits = {
	vk.VK_SAMPLE_COUNT_1_BIT,
	vk.VK_SAMPLE_COUNT_2_BIT,
	vk.VK_SAMPLE_COUNT_4_BIT,
	vk.VK_SAMPLE_COUNT_8_BIT,
	vk.VK_SAMPLE_COUNT_16_BIT,
	vk.VK_SAMPLE_COUNT_32_BIT,
	vk.VK_SAMPLE_COUNT_64_BIT,
}
function VKPhysDev:getMaxUsableSampleCount(...)
	local props = self:getProps(...)
	local counts = bit.band(props.limits.framebufferColorSampleCounts, props.limits.framebufferDepthSampleCounts)
	for i=#sampleCountBits,2,-1 do	-- skip 1. why even store it. why even store in-order and not in reversed-order?
		local sampleCountBit = sampleCountBits[i]
		if 0 ~= bit.band(counts, sampleCountBit) then return sampleCountBit end
	end
	return vk.VK_SAMPLE_COUNT_1_BIT
end

function VKPhysDev:findMemoryType(mask, props)
	local memProps = self:getMemProps()
	for i=0,memProps.memoryTypeCount-1 do
		if bit.band(mask, bit.lshift(1, i)) ~= 0
		and bit.band(memProps.memoryTypes[i].propertyFlags, props) ~= 0
		then
			return i
		end
	end
	error "failed to find suitable memory type!"
end

function VKPhysDev:querySwapChainSupport(surface)
	return {
		capabilities = self:getSurfaceCapabilities(surface),
		formats = self:getSurfaceFormats(surface),
		presentModes = self:getSurfacePresentModes(surface),
	}
end

function VKPhysDev:checkDeviceExtensionSupport(deviceExtensions)
	local requiredExtensions = deviceExtensions:mapi(function(v)
		return true, ffi.string(v)
	end):setmetatable(nil)

	local physDevExts = self:getExtProps()
	for i=0,#physDevExts-1 do
		requiredExtensions[ffi.string(physDevExts.v[i].extensionName)] = nil
	end
	return next(requiredExtensions) == nil
end

function VKPhysDev:isDeviceSuitable(surface, deviceExtensions)
	local indices = self:findQueueFamilies(surface)
	local extensionsSupported = self:checkDeviceExtensionSupport(deviceExtensions)
	local swapChainAdequate
	if extensionsSupported then
		local swapChainSupport = self:querySwapChainSupport(surface)
		swapChainAdequate = #swapChainSupport.formats > 0 and #swapChainSupport.presentModes > 0
	end

	local features = self:getFeatures()
	return indices
		and extensionsSupported
		and swapChainAdequate
		and features.samplerAnisotropy ~= 0
end

function VKPhysDev:findQueueFamilies(surface)
	local indices = {}
	local queueFamilies = self:getQueueFamilyProperties()
--print('queueFamilies queueFlags', require 'ext.tolua'(queueFamilies:totable():mapi(function(f) return f.queueFlags end)))
	for i=0,#queueFamilies-1 do
		local f = queueFamilies.v[i]
		if 0 ~= bit.band(f.queueFlags, vk.VK_QUEUE_GRAPHICS_BIT) then
--print('index',i,'has VK_QUEUE_GRAPHICS_BIT')
			indices.graphicsFamily = i
		end

		if self:getSurfaceSupport(i, surface) then
--print('index', i, 'has surface support')
			indices.presentFamily = i
--		else
--print('index', i, 'does not have surface support')
		end

		if indices.graphicsFamily and indices.presentFamily then
			return indices
		end
	end
	error "couldn't find all indices"
end

return VKPhysDev
