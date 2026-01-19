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

local makeVkShaderModuleCreateInfo = makeStructCtor(
	'VkShaderModuleCreateInfo',
	{
		{
			name = 'code',
			-- TODO just replace all this with 'write(args, v)' to write two fields.
			notarray = true,
			ptrname = 'pCode',
			gen = function(v)
				return ffi.cast(uint32_t_ptr, v)
			end,
			also = function(args, v)
				args.codeSize = #v
			end,
		},
	}
)


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
		self.device.id,
		makeVkShaderModuleCreateInfo{
			code = code,
		},
		nil
	)
end

-- TODO in a wrapping .obj or something, use lua.make
-- glslangValidator -V shader.vert -o shader-vert.spv
-- glslangValidator -V shader.frag -o shader-frag.spv


function VKShaderModule:destroy()
	if self.id then
		vk.vkDestroyShaderModule(self.device.id, self.id, nil)
	end
	self.id = nil
end

function VKShaderModule:__gc()
	return self:destroy()
end

return VKShaderModule 
