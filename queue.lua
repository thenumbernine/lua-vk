local ffi = require 'ffi'
local class = require 'ext.class'
local assertindex = require 'ext.assert'.index
local vk = require 'vk'
local vkGet = require 'vk.util'.vkGet
local VKDevice = require 'vk.device'


local VkQueue = ffi.typeof'VkQueue'


local VKQueue = class()

function VKQueue:init(args)
	local device = assertindex(args, 'device')
	if VKDevice:isa(device) then device = device.id end
	
	local queueFamilyIndex = assertindex(args, 'family')
	local queueIndex = args.index or 0

	-- queues don't get gc'd so ...
	self.id = vkGet(VkQueue, nil, vk.vkGetDeviceQueue, device, queueFamilyIndex, queueIndex)
end

return VKQueue
