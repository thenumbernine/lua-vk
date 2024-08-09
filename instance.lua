local vk = require 'ffi.req' 'vulkan'

local VKInstance = require 'vk.raii'{
	ctype = 'VkInstance',
	createType = 'VkInstanceCreateInfo',
	create = vk.vkCreateInstance,
	destroy = vk.vkDestroyInstance,
}

return VKInstance
