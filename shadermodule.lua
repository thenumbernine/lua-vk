require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local path = require 'ext.path'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkGet = require 'vk.util'.vkGet
local vkassert = require 'vk.util'.vkassert
local makeStructCtor = require 'vk.util'.makeStructCtor


local uint32_t_ptr = ffi.typeof'uint32_t*'
local VkShaderModule = ffi.typeof'VkShaderModule'

-- TODO convert .code into .codeSize and .pCode ?
local makeVkShaderModuleCreateInfo = makeStructCtor'VkShaderModuleCreateInfo'


local VKShaderModule = class()

--[[
args:
	.device
	.code -or- .filename
--]]
function VKShaderModule:init(args)
	self.device = assert.index(args, 'device')

	local code = args.code
	if not code and args.filename then
		code = assert(path(args.filename):read())
	end
	assert(code, "failed to find code, you must provide a .code or a .filename")

	self.id, self.idptr = vkGet(
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

-- TODO in a wrapping .obj or something, use lua.make
-- glslangValidator -V shader.vert -o shader-vert.spv
-- glslangValidator -V shader.frag -o shader-frag.spv


function VKShaderModule:destroy()
	if self.id then
		vk.vkDestroyShaderModule(self.device, self.id, nil)
	end
	self.id = nil
end

function VKShaderModule:__gc()
	return self:destroy()
end

return VKShaderModule 
