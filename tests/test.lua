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
local VulkanApp = require 'vk.app'
return VulkanApp():run()
--]]
