-- helper
local class = require 'ext.class'

local VulkanBufferMemoryAndMapped = class()

function VulkanBufferMemoryAndMapped:init(bm, mapped)
	self.bm = assert(bm)
	self.mapped = assert(mapped)
end

return VulkanBufferMemoryAndMapped 
