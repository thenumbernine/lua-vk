-- helper not wrapper
local ffi = require 'ffi'
local class = require 'ext.class'
local vk = require 'vk'


local VulkanPhysicalDevice = class()

function VulkanPhysicalDevice:init(common, deviceExtensions)
	self.common = common
	local instance = common.instance
	local surface = common.surface

	local physDevs = instance.obj:getPhysDevs()
	print'devices:'
	for _,physDev in ipairs(physDevs) do
		local props = physDev:getProps()
		print('',
			ffi.string(props.deviceName)
			..' type='..tostring(props.deviceType)
		)
	end

	for _,physDev in ipairs(physDevs) do
		if self:isDeviceSuitable(physDev, surface, deviceExtensions) then
			self.obj = physDev
			return
		end
	end

	error "failed to find a suitable GPU"
end

-- static method
function VulkanPhysicalDevice:isDeviceSuitable(physDev, surface, deviceExtensions)
	local indices = self:findQueueFamilies(physDev, surface)
	local extensionsSupported = self:checkDeviceExtensionSupport(physDev, deviceExtensions)
	local swapChainAdequate
	if extensionsSupported then
		local swapChainSupport = self:querySwapChainSupport(physDev, surface)
		swapChainAdequate = #swapChainSupport.formats > 0 and #swapChainSupport.presentModes > 0
	end

	local features = physDev:getFeatures()
	return indices
		and extensionsSupported
		and swapChainAdequate
		and features.samplerAnisotropy ~= 0
end

-- static method
function VulkanPhysicalDevice:findQueueFamilies(physDev, surface)
	physDev = physDev or self.obj
	assert(physDev, "you must either call this as a member method or as a static method while passing a physDev")
	local indices = {}
	local queueFamilies = physDev:getQueueFamilyProperties()
--print('queueFamilies queueFlags', require 'ext.tolua'(queueFamilies:totable():mapi(function(f) return f.queueFlags end)))
	for i=0,#queueFamilies-1 do
		local f = queueFamilies.v[i]
		if 0 ~= bit.band(f.queueFlags, vk.VK_QUEUE_GRAPHICS_BIT) then
--print('index',i,'has VK_QUEUE_GRAPHICS_BIT')
			indices.graphicsFamily = i
		end

		if physDev:getSurfaceSupport(i, surface) then
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

-- static method
function VulkanPhysicalDevice:checkDeviceExtensionSupport(physDev, deviceExtensions)
	local requiredExtensions = deviceExtensions:mapi(function(v)
		return true, ffi.string(v)
	end):setmetatable(nil)

	local physDevExts = physDev:getExtProps()
	for i=0,#physDevExts-1 do
		requiredExtensions[ffi.string(physDevExts.v[i].extensionName)] = nil
	end
	return next(requiredExtensions) == nil
end

-- static method
function VulkanPhysicalDevice:querySwapChainSupport(physDev, surface)
	physDev = physDev or self.obj
	return {
		capabilities = physDev:getSurfaceCapabilities(surface),
		formats = physDev:getSurfaceFormats(surface),
		presentModes = physDev:getSurfacePresentModes(surface),
	}
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
function VulkanPhysicalDevice:getMaxUsableSampleCount(...)
	local props = self.obj:getProps(...)
	local counts = bit.band(props.limits.framebufferColorSampleCounts, props.limits.framebufferDepthSampleCounts)
	for i=#sampleCountBits,2,-1 do	-- skip 1. why even store it. why even store in-order and not in reversed-order?
		local sampleCountBit = sampleCountBits[i]
		if 0 ~= bit.band(counts, sampleCountBit) then return sampleCountBit end
	end
	return vk.VK_SAMPLE_COUNT_1_BIT
end

function VulkanPhysicalDevice:findDepthFormat()
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

function VulkanPhysicalDevice:findSupportedFormat(candidates, tiling, features)
	for _,format in ipairs(candidates) do
		local props = self.obj:getFormatProps(format)
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

function VulkanPhysicalDevice:findMemoryType(mask, props)
	local memProps = self.obj:getMemProps()
	for i=0,memProps.memoryTypeCount-1 do
		if bit.band(mask, bit.lshift(1, i)) ~= 0
		and bit.band(memProps.memoryTypes[i].propertyFlags, props) ~= 0
		then
			return i
		end
	end
	error "failed to find suitable memory type!"
end



return VulkanPhysicalDevice 
