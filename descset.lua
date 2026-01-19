local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkDescriptorSet_array = ffi.typeof'VkDescriptorSet[?]'
local makeVkDescriptorSetAllocateInfo = makeStructCtor(
	'VkDescriptorSetAllocateInfo',
	{
		{
			name = 'setLayouts',
			ptrname = 'pSetLayouts',
			countname = 'descriptorSetCount',
			type = 'VkDescriptorSetLayout',
		},
		-- single-arg alternative to setLayouts
		{
			name = 'setLayout',
			ptrname = 'pSetLayouts',
			type = 'VkDescriptorSetLayout[1]',
			notarray = true,
			also = function(args)
				args.descriptorSetCount = 1
			end,
		},
	}
)


local VKDescSet = class()

function VKDescSet:init(args)
	self.device = assert.index(args, 'device')
	args.device = nil

	self.descriptorPool = args.descriptorPool
	args.descriptorPool = self.descriptorPool.id

	if args.descriptorSetCount then
		self.count = args.descriptorSetCount
	elseif args.setLayouts then
		self.count = #args.setLayouts
	elseif args.setLayout then
		self.count = 1
	else
		error("idk how to count the size of the descriptorSets")
	end

	-- same as vk.cmdbuf
	self.idptr = VkDescriptorSet_array(self.count)
	vkassert(
		vk.vkAllocateDescriptorSets,
		self.device.id,
		makeVkDescriptorSetAllocateInfo(args),
		self.idptr
	)
	self.id = self.idptr[0]
end

function VKDescSet:destroy()
	if self.idptr then
		vk.vkFreeDescriptorSets(self.device.id, self.descriptorPool.id, self.count, self.idptr)
	end
	self.id = nil
	self.idptr = nil
end

--[[ automatic? even manual seems not needed.
function VKDescriptorSet:__gc()
	return self:destroy()
end
--]]

return VKDescSet
