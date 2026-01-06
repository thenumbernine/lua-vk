local ffi = require 'ffi'
local class = require 'ext.class'
local path = require 'ext.path'
local vk = require 'vk'
local vkGet = require 'vk.util'.vkGet
local vkassert = require 'vk.util'.vkassert


local char_const_ptr = ffi.typeof'char const *'
local uint32_t_ptr = ffi.typeof'uint32_t*'
local VkShaderModuleCreateInfo_1 = ffi.typeof'VkShaderModuleCreateInfo[1]'
local VkShaderModule = ffi.typeof'VkShaderModule'


local VulkanShaderModule = class()

-- TODO lua.make here
-- glslangValidator -V shader.vert -o shader-vert.spv
-- glslangValidator -V shader.frag -o shader-frag.spv
function VulkanShaderModule:fromFile(device, filename)
	self.code = assert(path(filename):read())
	self.info = ffi.new(VkShaderModuleCreateInfo_1, {{
		sType = vk.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
		codeSize = #self.code,
		pCode = ffi.cast(uint32_t_ptr, ffi.cast(char_const_ptr, self.code)),
	}})
	local result = vkGet(VkShaderModule, vkassert, vk.vkCreateShaderModule, device, self.info, nil)
	self.info = nil
	self.code = nil
	return result
end

return VulkanShaderModule
