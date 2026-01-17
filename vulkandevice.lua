-- helper not wrapper
local ffi = require 'ffi'
local class = require 'ext.class'
local table = require 'ext.table'
local vk = require 'vk'
local VKDevice = require 'vk.device'


local VulkanDevice = class()

function VulkanDevice:init(physDev, deviceExtensions, enabledLayers, indices)
	self.obj = VKDevice{
		physDev = physDev,
		queueCreateInfos = table.keys{
			[indices.graphicsFamily] = true,
			[indices.presentFamily] = true,
		}:mapi(function(queueFamily)
			return {
				queueFamilyIndex = queueFamily,
				queuePriorities = {1},
			}
		end),
		enabledLayers = enabledLayers,
		enabledExtensions = deviceExtensions,
		enabledFeatures = {
			samplerAnisotropy = vk.VK_TRUE,
		},
	}
end

return VulkanDevice
