-- helper
local class = require 'ext.class'

local VulkanBufferMemoryAndMapped = class()

function VulkanBufferMemoryAndMapped:init(bm, mapped)
	self.bm = bm
	self.mapped = mapped
end

return VulkanBufferMemoryAndMapped 
