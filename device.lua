require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assertindex = require 'ext.assert'.index
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local vkResult = require 'vk.util'.vkResult
local makeStructCtor = require 'vk.util'.makeStructCtor
local makeTableToArray = require 'vk.util'.makeTableToArray


local makeVkDeviceQueueCreateInfo = makeStructCtor(
	'VkDeviceQueueCreateInfo',
	{
		{
			name = 'queuePriorities',
			ptrname = 'pQueuePriorities',
			countname = 'queueCount',
			type = 'float',
		},
	}
)

local makeVkWriteDescriptorSet = makeStructCtor(
	'VkWriteDescriptorSet',
	--[[
	what a messed up struct ...
	"If the descriptor binding identified by dstSet 
		and dstBinding has a descriptor type of VK_DESCRIPTOR_TYPE_INLINE_UNIFORM_BLOCK, 
		then descriptorCount specifies the number of bytes to update."
	"Otherwise, descriptorCount is one of
		the number of elements in pImageInfo
		the number of elements in pBufferInfo
		the number of elements in pTexelBufferView
		... or some options related to pNext ...
	--]]	
	{
		{
			name = 'bufferInfos',
			type = 'VkDescriptorBufferInfo',
			ptrname = 'pBufferInfo',
			countname = 'descriptorCount',
			also = function(args)
				args.descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
			end,
		},
		{
			name = 'imageInfos',
			type = 'VkDescriptorImageInfo',
			ptrname = 'pImageInfo',
			countname = 'descriptorCount',
			also = function(args)
				args.descriptorType = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
			end,
		},
		-- single-arg alternatives to above
		{
			name = 'bufferInfo',
			type = 'VkDescriptorBufferInfo',
			ptrname = 'pBufferInfo',
			notarray = true,
			also = function(args)
				args.descriptorCount = 1
				args.descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
			end,
		},
		{
			name = 'imageInfo',
			type = 'VkDescriptorImageInfo',
			ptrname = 'pImageInfo',
			notarray = true,
			also = function(args)
				args.descriptorCount = 1
				args.descriptorType = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
			end,
		},
	}
)

local makeVkWriteDescriptorSetArray = makeTableToArray(
	'VkWriteDescriptorSet',
	makeVkWriteDescriptorSet 
)


local VkDevice = ffi.typeof'VkDevice'

local makeVkDeviceCreateInfo = makeStructCtor(
	'VkDeviceCreateInfo',
	{
		{
			name = 'queueCreateInfos',
			type = 'VkDeviceQueueCreateInfo',
			gen = makeVkDeviceQueueCreateInfo,
		},
		{
			name = 'enabledFeatures',
			ptrname = 'pEnabledFeatures',
			type = 'VkPhysicalDeviceFeatures',
			notarray = true,
		},
		-- also in instance:
		{
			name = 'enabledLayers',
			ptrname = 'ppEnabledLayerNames',
			countname = 'enabledLayerCount',
			type = 'char const*',
			gen = function(x)
				return ffi.cast('char const*', x)
			end,
		},
		{
			name = 'enabledExtensions',
			ptrname = 'ppEnabledExtensionNames',
			countname = 'enabledExtensionCount',
			type = 'char const*',
			gen = function(x)
				return ffi.cast('char const*', x)
			end,
		},
	}
)


local VKDevice = class()

function VKDevice:init(args)
	-- can I still pass args to ffi.new?  will it ignore extra fields?  seems alright ...
	local physDev = assertindex(args, 'physDev')
	args.physDev = nil

	self.id, self.idptr = vkGet(
		VkDevice,
		vkassert,
		vk.vkCreateDevice,
		physDev,
		makeVkDeviceCreateInfo(args),
		nil
	)
end

function VKDevice:waitIdle()
	return vkResult(vk.vkDeviceWaitIdle(self.id), 'vkDeviceWaitIdle')
end

function VKDevice:updateDescSets(...)
	local x = ...
	if type(x) == 'table' then
		local count, arr = makeVkWriteDescriptorSetArray(x)
		vk.vkUpdateDescriptorSets(self.id, count, arr, 0, nil)
	else
		vk.vkUpdateDescriptorSets(self.id, ...)
	end
end

local makeVkAcquireNextImageInfoKHR = makeStructCtor'VkAcquireNextImageInfoKHR'
VKDevice.makeVkAcquireNextImageInfoKHR = makeVkAcquireNextImageInfoKHR 
function VKDevice:acquireNextImage(...)
	return vkResult(vk.vkAcquireNextImage2KHR(self.id, ...), 'vkAcquireNextImage2KHR')
end

function VKDevice:destroy()
	if self.id then
		vk.vkDestroyDevice(self.id, nil)
	end
	self.id = nil
end

function VKDevice:__gc()
	return self:destroy()
end

-- helper functions

function VKDevice:makeQueue(args, ...)
	args = args or {}
	args.device = self.id
	local VKQueue = require 'vk.queue'
	return VKQueue(args, ...)
end

function VKDevice:makeCmdPool(args, ...)
	args = args or {}
	args.device = self.id
	local VKCmdPool = require 'vk.cmdpool'
	return VKCmdPool(args, ...)
end

function VKDevice:makeSwapchain(args, ...)
	args = args or {}
	args.device = self
	local VKSwapchain = require 'vk.swapchain'
	return VKSwapchain(args, ...)
end

function VKDevice:makeRenderPass(args, ...)
	args = args or {}
	args.device = self.id
	local VKRenderPass = require 'vk.renderpass'
	return VKRenderPass(args, ...)
end

-- TODO rename file
function VKDevice:makeMem(args, ...)
	args = args or {}
	args.device = self
	local VKMemory = require 'vk.memory'
	return VKMemory(args, ...)
end

function VKDevice:makeBuffer(args, ...)
	args = args or {}
	args.device = self
	local VKBuffer = require 'vk.buffer'
	return VKBuffer(args, ...)
end

function VKDevice:makeFramebuffer(args, ...)
	args = args or {}
	args.device = self.id
	local VKFramebuffer = require 'vk.framebuffer'
	return VKFramebuffer(args, ...)
end

function VKDevice:makeImage(args, ...)
	args = args or {}
	args.device = self
	local VKImage = require 'vk.image'
	return VKImage(args, ...)
end

function VKDevice:makeImageFromStaged(args, ...)
	args = args or {}
	args.device = self
	local VKImage = require 'vk.image'
	return VKImage:makeFromStaged(args, ...)
end

-- make an image from an already-existing VkImage and don't destroy it upon gc
function VKDevice:makeImageFromID(imageID)
	local VKImage = require 'vk.image'
	return setmetatable({
		device = self,
		id = imageID,
		idptr = ffi.new('VkImage[1]', imageID),
		-- don't destroy
		destroy = function() end,
	}, VKImage)
end

function VKDevice:makeSampler(args, ...)
	args = args or {}
	args.device = self
	local VKSampler = require 'vk.sampler'
	return VKSampler(args, ...)
end

function VKDevice:makeFence(args, ...)
	args = args or {}
	args.device = self
	local VKFence = require 'vk.fence'
	return VKFence(args, ...)
end

-- rename this too?
function VKDevice:makeSemaphore(args, ...)
	args = args or {}
	args.device = self
	local VKSemaphore = require 'vk.semaphore'
	return VKSemaphore(args, ...)
end

-- TODO rename file
function VKDevice:makeDescPool(args, ...)
	args = args or {}
	args.device = self
	local VKDescriptorPool = require 'vk.descriptorpool'
	return VKDescriptorPool(args, ...)
end

-- TODO rename file
function VKDevice:makeDescSetLayout(args, ...)
	args = args or {}
	args.device = self
	local VKDescriptorSetLayout = require 'vk.descriptorsetlayout'
	return VKDescriptorSetLayout(args, ...)
end


function VKDevice:makePipeline(args, ...)
	args = args or {}
	args.device = self
	local VKPipeline = require 'vk.pipeline'
	return VKPipeline(args, ...)
end

function VKDevice:makePipelineLayout(args, ...)
	args = args or {}
	args.device = self
	local VKPipelineLayout = require 'vk.pipelinelayout'
	return VKPipelineLayout(args, ...)
end

-- TODO rename file
function VKDevice:makeShader(args, ...)
	args = args or {}
	args.device = self
	local VKShaderModule = require 'vk.shadermodule'
	return VKShaderModule(args, ...)
end

return VKDevice
