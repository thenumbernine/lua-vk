-- this isn't a wrapper class to the Vk classes
-- it's just a helper, and itself wraps 'mesh.objloader'
local ffi = require 'ffi'
local class = require 'ext.class'
local asserteq = require 'ext.assert'.eq
local vector = require 'ffi.cpp.vector-lua'
local ObjLoader = require 'mesh.objloader'
local VulkanDeviceMemoryBuffer = require 'vk.vulkandevicememorybuffer'


local vk = require 'vk'
local VkVertexInputBindingDescription = ffi.typeof'VkVertexInputBindingDescription'
local VkVertexInputAttributeDescription = ffi.typeof'VkVertexInputAttributeDescription'
local struct = require 'struct'
local vec3f = require 'vec-ffi.vec3f'
local VulkanVertex
VulkanVertex = struct{
	name = 'VulkanVertex',
	fields = {
		{name = 'pos', type = 'vec3f_t'},
		{name = 'color', type = 'vec3f_t'},
		{name = 'texCoord', type = 'vec3f_t'},
	},
	metatable = function(mt)
		mt.getBindingDescription = function()
			local result = VkVertexInputBindingDescription()
			result.binding = 0
			result.stride = ffi.sizeof(VulkanVertex)
			resultinputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX
			return result
		end

		mt.getAttributeDescriptions = function()
			local result = vector(VkVertexInputAttributeDescription)
			local v = result:emplace_back()
			v.location = 0
			v.binding = 0
			v.format = vk.VK_FORMAT_R32G32B32_SFLOAT
			v.offset = ffi.offsetof(VulkanVertex, 'pos')
			local v = result:emplace_back()
			v.location = 1
			v.binding = 0
			v.format = vk.VK_FORMAT_R32G32B32_SFLOAT
			v.offset = ffi.offsetof(VulkanVertex, 'color')
			local v = result:emplace_back()
			v.location = 2
			v.binding = 0
			v.format = vk.VK_FORMAT_R32G32B32_SFLOAT
			v.offset = ffi.offsetof(VulkanVertex, 'texCoord')
			return result
		end
	end,
}


local VulkanMesh = class()
VulkanMesh.VulkanVertex = VulkanVertex

function VulkanMesh:init(physDev, device, commandPool)
	local mesh = ObjLoader():load"viking_room.obj";

	local indices = mesh.triIndexes	-- vector'int32_t'
	asserteq(indices.type, ffi.typeof'int32_t') 	-- well, uint, but whatever
	-- copy from MeshVertex_t to VulkanVertex ... TODO why bother ...
	local vertices = vector(VulkanVertex)
	vertices:resize(#mesh.vtxs)
	for i=0,#mesh.vtxs-1 do
		local srcv = mesh.vtxs.v[i]
		local dstv = vertices.v[i]
		dstv.pos = srcv.pos
		dstv.texCoord = srcv.texcoord	-- TODO y-flip?
		dstv.color:set(1, 1, 1)	-- do our objects have normal properties?  nope, just v vt vn ... why doesn't the demo use normals? does it bake lighting?
	end

	local VulkanDevice = require 'vk.vulkandevice'
	if VulkanDevice:isa(device) then device = device.obj end
	local VKDevice = require 'vk.device'
	if VKDevice:isa(device) then device = device.id end

	self.vertexBufferAndMemory = VulkanDeviceMemoryBuffer:makeBufferFromStaged(
		physDev,
		device,
		commandPool,
		vertices.v,
		vertices:getNumBytes(),
		bit.bor(
			vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
			vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT
		)
	)

	self.numIndices = #indices
	self.indexBufferAndMemory = VulkanDeviceMemoryBuffer:makeBufferFromStaged(
		physDev,
		device,
		commandPool,
		indices.v,
		indices:getNumBytes(),
		bit.bor(
			vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
			vk.VK_BUFFER_USAGE_INDEX_BUFFER_BIT
		)
	)
end

function VulkanMesh:destroy()
	if self.vertexBufferAndMemory then
		self.vertexBufferAndMemory:destroy()
	end
	if self.indexBufferAndMemory then
		self.indexBufferAndMemory:destroy()
	end
	self.vertexBufferAndMemory = nil
	self.indexBufferAndMemory = nil
end

return VulkanMesh
