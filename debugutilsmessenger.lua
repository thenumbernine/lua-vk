require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor


local PFN_vkDebugUtilsMessengerCallbackEXT = ffi.typeof'PFN_vkDebugUtilsMessengerCallbackEXT'
local VkDebugUtilsMessengerEXT = ffi.typeof'VkDebugUtilsMessengerEXT'
local makeVkDebugUtilsMessengerCreateInfoEXT = makeStructCtor'VkDebugUtilsMessengerCreateInfoEXT'


local DebugUtilsMesseger = class()

function DebugUtilsMesseger:init(args)
	local instance = assert.index(args, 'instance')
	args.instance = nil
	local instanceID = instance.id
	self.instance = instanceID

	-- expect it to be a Lua function
	-- cast it / create closure and store it so it doesn't gc (but don't they have to manually free?)
	if args.userCallback then
		self.userCallback = args.userCallback	-- do you need to make sure the function doesn't gc, or just the closure?  but the closure doesn't because it must be manually freed...
		self.userCallbackClosure = ffi.cast(PFN_vkDebugUtilsMessengerCallbackEXT, jit.off(args.userCallback))
		args.pfnUserCallback = self.userCallbackClosure
	end

	self.vkCreateDebugUtilsMessengerEXT = instance:getProcAddr'vkCreateDebugUtilsMessengerEXT'
	self.vkDestroyDebugUtilsMessengerEXT = instance:getProcAddr'vkDestroyDebugUtilsMessengerEXT'

	self.id, self.idptr = vkGet(
		VkDebugUtilsMessengerEXT,
		vkassert,
		self.vkCreateDebugUtilsMessengerEXT,
		instanceID,
		makeVkDebugUtilsMessengerCreateInfoEXT(args),
		nil
	)
end

function DebugUtilsMesseger:destroy()
	if self.id and self.vkDestroyDebugUtilsMessengerEXT then
		self.vkDestroyDebugUtilsMessengerEXT(self.instance, self.id, nil)
	end
	self.id = nil
	self.idptr = nil
	
	if self.userCallbackClosure then
		self.userCallbackClosure:free()
	end
	self.userCallbackClosure =  nil
end

function DebugUtilsMesseger:__gc()
	return self:destroy()
end

return DebugUtilsMesseger 
