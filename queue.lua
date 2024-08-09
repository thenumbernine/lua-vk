local ffi = require 'ffi'
local class = require 'ext.class'
local assertindex = require 'ext.assert'.index
local vk = require 'ffi.req' 'vulkan'
local vkassert = require 'vk.util'.vkassert
local VKDevice = require 'vk.device'

local VKQueue = class()

function VKQueue:init(args)
	local device = assertindex(args, 'device')
	if VKDevice:isa(device) then device = device.id end
	
	local queueFamilyIndex = assertindex(args, 'family')
	local queueIndex = args.index or 0

	-- queues don't get gc'd so ...
	local ptr = ffi.new'VkQueue[1]'
	vk.vkGetDeviceQueue(device, queueFamilyIndex, queueIndex, ptr)
	self.id = ptr[0]
end

return VKQueue
