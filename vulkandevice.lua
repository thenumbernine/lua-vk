-- helper not wrapper
local ffi = require 'ffi'
local class = require 'ext.class'
local table = require 'ext.table'
local assertindex = require 'ext.assert'.index
local vector = require 'ffi.cpp.vector-lua'
local vk = require 'vk'
local defs = require 'vk.defs'
local makeStructCtor = require 'vk.util'.makeStructCtor
local VKDevice = require 'vk.device'

local float_1 = ffi.typeof'float[1]'

local VulkanDevice = class()

function VulkanDevice:init(physDev, deviceExtensions, enableValidationLayers, indices)
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
		enabledLayers = table{
			enableValidationLayers and assertindex(defs, 'validationLayer') or nil
		},
		enabledExtensions = deviceExtensions,
		enabledFeatures = {
			samplerAnisotropy = vk.VK_TRUE,
		},
	}
end

return VulkanDevice
