-- another one that doesn't use raii for anything
-- but it does use the info ctor

local class = require 'ext.class'

local VKSwapchain = class()

VKSwapchain.createType = 'VkSwapchainCreateInfoKHR'
require 'vk.util'.addInitFromArgs(VKSwapchain)

function VKSwapchain:init(args)
	local device = assertexists(args, 'device')
	local VKDevice = require 'vk.device'
	if VKDevice:isa(device) then device = device.id end

	local info = self:initFromArgs(args)

	self.gc = ffi.new'VkSwapchainKHR[1]'
	vkassert(vk.vkCreateSwapchainKHR, device, info, nil, self.gc)
	self.id = self.gc[0]
end

return VKSwapchain
