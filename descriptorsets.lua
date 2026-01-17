local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkDescriptorSet_array = ffi.typeof'VkDescriptorSet[?]'
local makeVkDescriptorSetAllocateInfo = makeStructCtor'VkDescriptorSetAllocateInfo'


local VKDescriptorSets = class()

function VKDescriptorSets:init(args)
	local device = assert.index(args, 'device')
	args.device = nil
	local VulkanDevice = require 'vk.vulkandevice'
	if VulkanDevice:isa(device) then device = device.obj end
	local VKDevice = require 'vk.device'
	if VKDevice:isa(device) then device = device.id end
	self.device = device

	self.count = assert.index(args, 'descriptorSetCount')
	-- same as vk.commandbuffers
	self.idptr = VkDescriptorSet_array(self.count)
	vkassert(
		vk.vkAllocateDescriptorSets,
		self.device,
		makeVkDescriptorSetAllocateInfo(args),
		self.idptr
	)
	self.id = self.idptr[0]
end

-- destroy?

return VKDescriptorSets
