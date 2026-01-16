require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkGet = require 'vk.util'.vkGet
local vkassert = require 'vk.util'.vkassert
local makeStructCtor = require 'vk.util'.makeStructCtor

local uint32_t_ptr = ffi.typeof'uint32_t*'
local VkShaderModule = ffi.typeof'VkShaderModule'

local makeVkShaderModuleCreateInfo = makeStructCtor'VkShaderModuleCreateInfo'


local VKShaderModule = class()

function VKShaderModule:init(args)
	self.device = assert.index(args, 'device')
	local code = assert.index(args, 'code')
	self.id = vkGet(
		VkShaderModule,
		vkassert,
		vk.vkCreateShaderModule,
		self.device,
		makeVkShaderModuleCreateInfo{
			codeSize = #code,
			pCode = ffi.cast(uint32_t_ptr, code),
		},
		nil
	)
end

function VKShaderModule:destroy()
	if self.id then
		vk.vkDestroyShaderModule(self.device, self.id, nil)
	end
	self.id = nil
end

VKShaderModule.__gc = VKShaderModule.destroy

return VKShaderModule 
