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

--[[
static generator method
args:
	device
	filename
--]]
function VKShaderModule:fromFile(args)
	local path = require 'ext.path'
	return VKShaderModule{
		device = args.device,
		code = assert(path(assert.index(args, 'filename')):read()),
	}
end
-- TODO in a wrapping .obj or something, use lua.make
-- glslangValidator -V shader.vert -o shader-vert.spv
-- glslangValidator -V shader.frag -o shader-frag.spv


function VKShaderModule:destroy()
	if self.id then
		vk.vkDestroyShaderModule(self.device, self.id, nil)
	end
	self.id = nil
end

VKShaderModule.__gc = VKShaderModule.destroy

return VKShaderModule 
