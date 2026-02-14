-- helper
require 'ext.gc'
local ffi = require 'ffi'
local assert = require 'ext.assert'
local class = require 'ext.class'
local table = require 'ext.table'
local vk = require 'vk'
local VKInstance = require 'vk.instance'
local VulkanSwapchain = require 'vk.vulkanswapchain'


local validationLayerNames = {
	'VK_LAYER_KHRONOS_validation'
}

-- but why not just use bitfields? meh
local function VK_MAKE_VERSION(major, minor, patch)
	return bit.bor(bit.lshift(major, 22), bit.lshift(minor, 12), patch)
end
local function VK_MAKE_API_VERSION(variant, major, minor, patch)
	return bit.bor(bit.lshift(variant, 29), bit.lshift(major, 22), bit.lshift(minor, 12), patch)
end


local VKEnv = class()

function VKEnv:init(args)
	local enableValidationLayers = args.enableValidationLayers
	if enableValidationLayers == nil then
		enableValidationLayers = self.enableValidationLayers
	end

	local enabledLayers = table()
	do
		local layerProps = VKInstance:getLayerProps()
--DEBUG:print'vulkan layers:'
--DEBUG:for _,layerProp in ipairs(layerProps) do
--DEBUG:	print('',layerProp.layerName, layerProp.description)
--DEBUG:end

		local enabledExtensions = VKInstance:getExts()

--DEBUG:print'vulkan enabledExtensions:'
--DEBUG:for _,s in ipairs(enabledExtensions) do
--DEBUG:	print('', s)
--DEBUG:end

		if enableValidationLayers then
			for _,layerName in ipairs(validationLayerNames) do
				if not layerProps:find(nil, function(layerProp) return layerProp.layerName == layerName end) then
					error("validation layer "..layerName.." requested, but not available!")
				end
			end

			enabledExtensions:insert'VK_EXT_debug_utils'
			enabledLayers:append(validationLayerNames)
		end

		self.instance = VKInstance{
			applicationInfo = {
				pApplicationName = args.title or '',
				applicationVersion = VK_MAKE_API_VERSION(0, 1, 0, 0),
				pEngineName = 'no engine',
				engineVersion = VK_MAKE_API_VERSION(0, 1, 0, 0),
				apiVersion = VK_MAKE_API_VERSION(0, 1, 0, 0),
			},
			enabledLayers = enabledLayers,
			enabledExtensions = enabledExtensions,
		}
	end

	-- debug:
	if enableValidationLayers then
		self.debug = self.instance:makeDebugUtilsMessenger{
			messageSeverity = bit.bor(
				vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT,
				--vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT,
				vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT,
				vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT
			),
			messageType = bit.bor(
				vk.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT,
				vk.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT,
				vk.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT
				--vk.VK_DEBUG_UTILS_MESSAGE_TYPE_DEVICE_ADDRESS_BINDING_BIT_EXT
			),
			userCallback = function(
				messageSeverity,	-- VkDebugUtilsMessageSeverityFlagBitsEXT
				messageTypes,		-- VkDebugUtilsMessageTypeFlagsEXT
				pCallbackData,		-- const VkDebugUtilsMessengerCallbackDataEXT*
				pUserData			-- void*
			) -- returns VkBool32
				-- this is run on the same thread? or no?
				io.stderr:write("validation layer: ", ffi.string(pCallbackData.pMessage), '\n')
				return vk.VK_FALSE
			end,
		}
	end

	self.surface = self.instance:makeSurface{
		window = args.window,
	}

--DEBUG:print'devices:'
--DEBUG:for _,physDev in ipairs(self.instance:getPhysDevs()) do
--DEBUG:	local props = physDev:getProps()
--DEBUG:	print('',
--DEBUG:		ffi.string(props.deviceName)
--DEBUG:		..' type='..tostring(props.deviceType)
--DEBUG:	)
--DEBUG:end

	local deviceExtensions = table{
		'VK_KHR_swapchain',
	}

	self.physDev = assert(select(2, self.instance
		:getPhysDevs()
		:find(nil, function(physDev)
			return physDev:isDeviceSuitable(self.surface, deviceExtensions)
		end)),
		"failed to find a suitable GPU")

	self.msaaSamples = self.physDev:getMaxUsableSampleCount()
--DEBUG:print('msaaSamples', self.msaaSamples)

	local queueFamilyIndices = self.physDev:findQueueFamilies(self.surface)

	self.device = self.physDev:makeDevice{
		queueCreateInfos = table.keys{
			[queueFamilyIndices.graphicsFamily] = true,
			[queueFamilyIndices.presentFamily] = true,
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
	self.instance.autodestroys:insert(self.device)
	-- or TODO maybe just use vkenv.autodestroys?
	-- or merge instance's autodestroys with device's as well?

	self.graphicsQueue = self.device:makeQueue{
		family = queueFamilyIndices.graphicsFamily,
	}

	self.presentQueue = self.device:makeQueue{
		family = queueFamilyIndices.presentFamily,
	}

	self.cmdPool = self.device:makeCmdPool{
		flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
		queueFamilyIndex = assert.index(self.physDev:findQueueFamilies(self.surface), 'graphicsFamily'),
	}

	self:resetSwapchain(
		assert(args.width),
		assert(args.height)
	)
end

function VKEnv:resetSwapchain(width, height)
	if self.swapchain then
		self.swapchain:destroy()
	end
	self.swapchain = VulkanSwapchain{
		width = assert(width),
		height = assert(height),
		physDev = self.physDev,
		device = self.device,
		surface = self.surface,
		msaaSamples = self.msaaSamples,
	}
end

function VKEnv:exit()
	if self.device then
		assert(self.device:waitIdle())
	end

	if self.swapchain then
		self.swapchain:destroy()
	end

	if self.instance then
		self.instance:destroy()
	end

	self.swapchain = nil
	self.device = nil
	self.instance = nil

	-- don't need to call again on gc
	self.__gc = function() end
end

function VKEnv:__gc()
	return self:exit()
end

-- helper function

-- static function
function VKEnv:buildShader(src, dst)
	local os = require 'ext.os'
	local Targets = require 'make.targets'
	local targets = Targets()
	targets:add{
		dsts = {dst},
		srcs = {src},
		rule = function(r)
			os.exec('glslangValidator -V "'..r.srcs[1]..'" -o "'..r.dsts[1]..'"')
		end,
	}
	targets:run(dst)
end

return VKEnv
