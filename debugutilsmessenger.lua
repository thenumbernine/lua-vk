require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor


local PFN_vkCreateDebugUtilsMessengerEXT = ffi.typeof'PFN_vkCreateDebugUtilsMessengerEXT'
local PFN_vkDestroyDebugUtilsMessengerEXT = ffi.typeof'PFN_vkDestroyDebugUtilsMessengerEXT'
local PFN_vkDebugUtilsMessengerCallbackEXT = ffi.typeof'PFN_vkDebugUtilsMessengerCallbackEXT'
local VkDebugUtilsMessengerEXT = ffi.typeof'VkDebugUtilsMessengerEXT'
local makeVkDebugUtilsMessengerCreateInfoEXT = makeStructCtor'VkDebugUtilsMessengerCreateInfoEXT'


local DebugUtilsMesseger = class()

function DebugUtilsMesseger:init(args)
	local instance = assert.index(args, 'instance')
	args.instance = nil
	instance = instance.obj or instance  
	instance = instance.id or instance  
	self.instance = instance

	-- expect it to be a Lua function
	-- cast it / create closure and store it so it doesn't gc (but don't they have to manually free?)
	if args.userCallback then
		self.userCallbackClosure = ffi.cast(PFN_vkDebugUtilsMessengerCallbackEXT, args.userCallback)
		args.pfnUserCallback = self.userCallbackClosure
		args.userCallback = nil
	end

	self.vkCreateDebugUtilsMessengerEXT = ffi.cast(
		PFN_vkCreateDebugUtilsMessengerEXT,
		vk.vkGetInstanceProcAddr(
			instance,
			'vkCreateDebugUtilsMessengerEXT'
		)
	)
	self.vkDestroyDebugUtilsMessengerEXT = ffi.cast(
		PFN_vkDestroyDebugUtilsMessengerEXT,
		vk.vkGetInstanceProcAddr(
			instance,
			'vkDestroyDebugUtilsMessengerEXT'
		)
	)

	self.id = vkGet(
		VkDebugUtilsMessengerEXT,
		vkassert,
		self.vkCreateDebugUtilsMessengerEXT,
		instance,
		makeVkDebugUtilsMessengerCreateInfoEXT(args),
		nil
	)
end

function DebugUtilsMesseger:destroy()
	if self.id and self.vkDestroyDebugUtilsMessengerEXT then
		self.vkDestroyDebugUtilsMessengerEXT(self.instance, self.id, nil)
	end
	self.id = nil
	
	if self.userCallbackClosure then
		self.userCallbackClosure:free()
	end
	self.userCallbackClosure =  nil
end

DebugUtilsMesseger.__gc = DebugUtilsMesseger.destroy

return DebugUtilsMesseger 
