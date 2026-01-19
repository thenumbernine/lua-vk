--[[
this and swapchain have similar dtor paired with device, and createinfo
surface is sort of similar, paired with instance, but no createinfo
--]]
require 'ext.gc'	-- make sure luajit can __gc lua-tables
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
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
	local device = assert.index(args, 'device')
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

--[[
static
args used by staging:
	device
	physDev
	size
	data
	queue
	cmdPool
args overridden before VKBuffer:init:
	memProps
	data
all others forwarded to VKBuffer:init
--]]
function VKBuffer:makeFromStaged(args)
	local staging = VKBuffer{
		device = args.device,
		size = assert.index(args, 'size'),
		usage = vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
		-- memory fields:
		physDev = args.physDev,
		memProps = bit.bor(
			vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
			vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
		),
		data = args.data,
	}

	args.data = nil
	args.memProps = vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
	local buffer = VKBuffer(args)

	args.queue:copyBuffer(
		args.cmdPool,
		staging,
		buffer,
		args.size
	)

	staging:destroy()

	return buffer
end

return VKBuffer
