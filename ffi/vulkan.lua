local ffi = require 'ffi'
if ffi.os == 'Android' and ffi.arch == 'arm' then
	-- or is this just vulkan for all x32?
	return require 'vk.ffi.vulkan_Android_arm'
end
return require 'vk.ffi/vulkan_Linux_x64'
