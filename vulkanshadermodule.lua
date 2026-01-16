local class = require 'ext.class'
local path = require 'ext.path'
local VKShaderModule = require 'vk.shadermodule'


local VulkanShaderModule = class()

-- static method.
-- TODO lua.make here
-- glslangValidator -V shader.vert -o shader-vert.spv
-- glslangValidator -V shader.frag -o shader-frag.spv
function VulkanShaderModule:fromFile(device, filename)
	return VKShaderModule{
		device = device,
		code = assert(path(filename):read()),
	}
end

return VulkanShaderModule
