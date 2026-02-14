-- same trick as gl.debug, use luajit -lvk.debug ... to debug vulkan envs
require 'vk.env'.enableValidationLayers = true
