local table = require 'ext.table'
local sdl = require 'sdl'
local VKEnv = require 'vk.env'
local SDLApp = require 'sdl.app'

-- TODO move view and orbit out of glapp ... but to where ...
-- seems like we're going to need a geometry library soon ...
-- TODO should glapp.view always :subclass() for you? like glapp.orbit and imgui.withorbit already do?
local VulkanApp = require 'glapp.view'.apply(SDLApp):subclass()

VulkanApp.title = 'Vulkan App'

VulkanApp.sdlCreateWindowFlags = bit.bor(
	VulkanApp.sdlCreateWindowFlags,
	sdl.SDL_WINDOW_VULKAN
)

function VulkanApp:initWindow()
	VulkanApp.super.initWindow(self)
	self:initVK()
end

-- default, feel free to override
function VulkanApp:initVK()
	local args = table(self.vkenvArgs):setmetatable(nil)
	-- for vkenv.surface
	args.window = self.window
	-- for vkenv:resetSwapchain()
	args.width = self.width
	args.height = self.height

	self.vkenv = VKEnv(args)
end


function VulkanApp:exit()
	if self.vkenv then 
		self.vkenv:exit() 
	end
	VulkanApp.super.exit(self)
end

return VulkanApp
