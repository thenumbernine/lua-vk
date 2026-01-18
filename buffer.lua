--[[
this and swapchain have similar dtor paired with device, and createinfo
surface is sort of similar, paired with instance, but no createinfo
--]]
require 'ext.gc'	-- make sure luajit can __gc lua-tables
local ffi = require 'ffi'
local class = require 'ext.class'
local assertindex = require 'ext.assert'.index
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local vkResult = require 'vk.util'.vkResult
local makeStructCtor = require 'vk.util'.makeStructCtor
local VKDevice = require 'vk.device'


local VkBuffer = ffi.typeof'VkBuffer'
local VkMemoryRequirements = ffi.typeof'VkMemoryRequirements'
local makeVkBufferCreateInfo = makeStructCtor'VkBufferCreateInfo'


local VKBuffer = class()

function VKBuffer:init(args)
	local device = assertindex(args, 'device')
	if VKDevice:isa(device) then device = device.id end

	args.sharingMode = args.sharingMode or vk.VK_SHARING_MODE_EXCLUSIVE

	self.device = device

	self.id = vkGet(
		VkBuffer,
		vkassert,
		vk.vkCreateBuffer,
		device,
		makeVkBufferCreateInfo(args),
		nil
	)

	-- under what circumstances does a VkBuffer need a VkMemory?
	-- always?
	if not args.dontMakeMem then
		-- needs args.physDev, args.memProps
		-- optionally args.data
		local VKMemory = require 'vk.memory'
		local memReq = self:getMemReq()
		local memory = VKMemory{
			device = device,
			-- is this same as args.size?
			allocationSize = memReq.size,
			memoryTypeIndex = args.physDev:findMemoryType(
				memReq.memoryTypeBits,
				args.memProps
			),
		}
		self.memory = memory

		assert(self:bindMemory(memory.id))
	
		if args.data then
			local size = args.size
			local dstData = memory:map(size)
			ffi.copy(dstData, args.data, size)
			memory:unmap()
		end
	end
end

function VKBuffer:getMemReq()
	return vkGet(
		VkMemoryRequirements,
		nil,
		vk.vkGetBufferMemoryRequirements,
		self.device,
		self.id
	)
end

function VKBuffer:bindMemory(mem)
	return vkResult(
		vk.vkBindBufferMemory(
			self.device,
			self.id,
			mem,
			0
		),
		'vkBindBufferMemory'
	)
end

function VKBuffer:destroy()
	if self.memory then
		self.memory:destroy()
	end
	self.memory = nil

	if self.id then
		vk.vkDestroyBuffer(self.device, self.id, nil)
	end
	self.id = nil
end

return VKBuffer
