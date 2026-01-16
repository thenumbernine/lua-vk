local ffi = require 'ffi'
local class = require 'ext.class'
local path = require 'ext.path'
local vk = require 'vk'
local vkGet = require 'vk.util'.vkGet
local vkassert = require 'vk.util'.vkassert


local uint32_t_ptr = ffi.typeof'uint32_t*'
local VkShaderModuleCreateInfo = ffi.typeof'VkShaderModuleCreateInfo'
local VkShaderModule = ffi.typeof'VkShaderModule'


local VulkanShaderModule = class()

-- TODO lua.make here
-- glslangValidator -V shader.vert -o shader-vert.spv
-- glslangValidator -V shader.frag -o shader-frag.spv
function VulkanShaderModule:fromFile(device, filename)
	local code = assert(path(filename):read())
	local info = VkShaderModuleCreateInfo()
	info.sType = vk.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO
	info.codeSize = #code
	info.pCode = ffi.cast(uint32_t_ptr, code)
	local result = vkGet(
		VkShaderModule,
		vkassert,
		vk.vkCreateShaderModule,
		device,
		info,
		nil
	)
	return result
end

return VulkanShaderModule
