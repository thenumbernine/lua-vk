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
local VKMemory = require 'vk.memory'


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
		local memReq = self:getMemReq()
		local mem = VKMemory{
			device = device,
			-- is this same as args.size?
			allocationSize = memReq.size,
			memoryTypeIndex = args.physDev:findMemoryType(
				memReq.memoryTypeBits,
				args.memProps
			),
		}
		self.mem = mem

		assert(self:bindMemory(mem.id))
	
		if args.data then
			local size = args.size
			local dstData = mem:map(size)
			ffi.copy(dstData, args.data, size)
			mem:unmap()
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
	if self.mem then
		self.mem:destroy()
	end
	self.mem = nil

	if self.id then
		vk.vkDestroyBuffer(self.device, self.id, nil)
	end
	self.id = nil
end

-- helper function

-- static function
function VKBuffer:makeFromStaged(args)
	local staging = VKBuffer{
		device = args.device,
		size = args.bufferSize,
		usage = vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
		-- memory fields:
		physDev = args.physDev,
		memProps = bit.bor(
			vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
			vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
		),
		data = args.srcData,
	}

	local buffer = VKBuffer{
		device = args.device,
		size = args.bufferSize,
		usage = args.usage,
		physDev = args.physDev,
		memProps = vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
	}

	args.queue:copyBuffer(
		args.commandPool,
		staging,
		buffer,
		args.bufferSize
	)

	staging:destroy()

	return buffer
end

return VKBuffer
