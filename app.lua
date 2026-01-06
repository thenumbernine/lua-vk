local sdl = require 'sdl'
local VulkanCommon = require 'vk.vulkancommon'

local SDLApp = require 'sdl.app'

-- TODO move view and orbit out of glapp ... but to where ...
-- seems like we're going to need a geometry library soon ...
-- TODO should glapp.view always :subclass() for you? like glapp.orbit and imgui.withorbit already do?
local VulkanApp = require 'glapp.view'.apply(SDLApp):subclass()

VulkanApp.title = 'Vulkan test'
VulkanApp.sdlCreateWindowFlags = bit.bor(
	VulkanApp.sdlCreateWindowFlags,
	sdl.SDL_WINDOW_VULKAN
)

function VulkanApp:initWindow()
	VulkanApp.super.initWindow(self)
	self.vkCommon = VulkanCommon(self)
print('VulkanApp:initWindow done')
end

function VulkanApp:postUpdate()
	self.vkCommon:drawFrame()
	VulkanApp.super.postUpdate(self)
end

function VulkanCommon:resize()
	self.vkCommon:setFramebufferResized()
end

function VulkanApp:exit()
	if self.vkCommon then self.vkCommon:exit() end
	VulkanApp.super.exit(self)
end

return VulkanApp
