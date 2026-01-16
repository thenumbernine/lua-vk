local ffi = require 'ffi'
local class = require 'ext.class'
local path = require 'ext.path'
local vk = require 'vk'
local vkGet = require 'vk.util'.vkGet
local vkassert = require 'vk.util'.vkassert
local makeStructCtor = require 'vk.util'.makeStructCtor


local uint32_t_ptr = ffi.typeof'uint32_t*'
local VkShaderModule = ffi.typeof'VkShaderModule'


local makeVkShaderModuleCreateInfo = makeStructCtor'VkShaderModuleCreateInfo'


local VulkanShaderModule = class()

-- TODO lua.make here
-- glslangValidator -V shader.vert -o shader-vert.spv
-- glslangValidator -V shader.frag -o shader-frag.spv
-- TODO return an obj ith id so I can :destroy() it
function VulkanShaderModule:fromFile(device, filename)
	local code = assert(path(filename):read())
	return vkGet(
		VkShaderModule,
		vkassert,
		vk.vkCreateShaderModule,
		device,
		makeVkShaderModuleCreateInfo{
			codeSize = #code,
			pCode = ffi.cast(uint32_t_ptr, code),
		},
		nil
	)
end

return VulkanShaderModule
