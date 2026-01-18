local ffi = require 'ffi'
local class = require 'ext.class'
local assertindex = require 'ext.assert'.index
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local vkResult = require 'vk.util'.vkResult
local makeStructCtor = require 'vk.util'.makeStructCtor
local makeTableToArray = require 'vk.util'.makeTableToArray
local VKPhysDev = require 'vk.physdev'


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
	if VKPhysDev:isa(physDev) then physDev = physDev.id end

	self.id = vkGet(
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

function VKDevice:destroy()
	if self.id then
		vk.vkDestroyDevice(self.id, nil)
	end
	self.id = nil
end

return VKDevice
