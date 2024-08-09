-- another one that doesn't use raii for anything
-- but it does use the info ctor
local ffi = require 'ffi'
local GCWrapper = require 'ffi.gcwrapper.gcwrapper'
local assertindex = require 'ext.assert'.index
local assertne = require 'ext.assert'.ne
local vk = require 'vk'
local VKDevice = require 'vk.device'

local vkassert = require 'vk.util'.vkassert
local vkGetVector = require 'vk.util'.vkGetVector

local ctype = 'VkSwapchainKHR'
local createType = 'VkSwapchainCreateInfoKHR'	-- for vk create 

-- for autorelease ptr 
-- NOTICE this highlights how the GCWrapper is nice for primitives only!
-- due to me making it to hand off the gcwrap'd ptr through ctor , and compare it with nullptr-compare
-- it is not very cohesive with using a struct
-- and sometimes dtors need extra info in addition to their pointer
-- and in those cases the dtor info needs to be a struct ...
local dtortype = 'autorelease_VkSwapchainKHR_dtor_t'
require 'struct'{
	name = dtortype,
	fields = {
		{name='swapchain', type='VkSwapchainKHR[1]'},
		{name='device', type='VkDevice'},
	},
}

local VKSwapchain = GCWrapper{
	gctype = 'autorelease_'..ctype..'_ptr_t',
	ctype = dtortype,
	release = function(ptr)
		if ptr[0].device == nil and ptr[0].swapchain[0] == nil then return end
		assertne(ptr[0].device, nil)
		assertne(ptr[0].swapchain[0], nil)
		vk.vkDestroySwapchainKHR(ptr[0].device, ptr[0].swapchain[0], nil)
	end,
}:subclass()

VKSwapchain.createType = createType 
require 'vk.util'.addInitFromArgs(VKSwapchain)

function VKSwapchain:init(args)
	local device = assertindex(args, 'device')
	if VKDevice:isa(device) then device = device.id end
	
	local dtorinit = ffi.new(dtortype)
	dtorinit.device = device

	local info = self:initFromArgs(args)
	vkassert(vk.vkCreateSwapchainKHR, device, info, nil, dtorinit.swapchain)

	VKSwapchain.super.init(self, dtorinit)
	
	self.id = self.gc.ptr[0].swapchain[0]
end

function VKSwapchain:getImages(device)
	if VKDevice:isa(device) then device = device.id end
	return vkGetVector('VkImage', vkassert, vk.vkGetSwapchainImagesKHR, device, self.id)
end

function VKSwapchain:destroy()
	vk.vkDestroySwapchainKHR(self.gc.ptr[0].device, self.gc.ptr[0].swapchain[0], nil)
	self.gc.ptr[0].swapchain[0] = nil
	self.gc.ptr[0].device = nil
end

return VKSwapchain
