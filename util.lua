local vk = require 'ffi.req' 'vulkan'

local function vkassert(f, ...)
	local res = f(...)
	if res ~= vk.VK_SUCCESS then
		error('failed with error '..tostring(res))
	end
end

return {
	vkassert = vkassert,
}
