#!/usr/bin/env luajit

-- [[ build shaders
local table = require 'ext.table'
local os = require 'ext.os'
local Targets = require 'make.targets'
local targets = Targets()
local fns = table{
	{src='shader.vert', dst='shader-vert.spv'},
	{src='shader.frag', dst='shader-frag.spv'},
}
for _,fn in ipairs(fns) do
	targets:add{
		dsts = {fn.dst},
		srcs = {fn.src},
		rule = function(r)
			os.exec('glslangValidator -V "'..r.srcs[1]..'" -o "'..r.dsts[1]..'"')
		end,
	}
end
targets:run(fns:mapi(function(fn) return fn.dst end):unpack())
--]]

-- [[ app
local VKEnv = require 'vk.env'
local VulkanApp = require 'vk.app':subclass()
VulkanApp.title = 'Vulkan test'

function VulkanApp:initVK()
	self.vkenv = VKEnv{
		app = self,
		enableValidationLayers = true,
		shaders = {
			vertexFile = 'shader-vert.spv',
			fragmentFile = 'shader-frag.spv',
		},
		-- TODO shader bindings I guess ... sampler, etc
		-- TODO mesh geometry stuff too
		mesh = 'viking_room.obj',
		tex = 'viking_room.png',
	}
end

return VulkanApp():run()
--]]
