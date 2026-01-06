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
local Vertex
Vertex = struct{
	name = 'Vertex',
	fields = {
		{name = 'pos', type = 'vec3f_t'},
		{name = 'color', type = 'vec3f_t'},
		{name = 'texCoord', type = 'vec3f_t'},
	},
	metatable = function(mt)
		mt.getBindingDescription = function()
			return ffi.new(VkVertexInputBindingDescription, {
				binding = 0,
				stride = ffi.sizeof(Vertex),
				inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX,
			})
		end

		mt.getAttributeDescriptions = function()
			return vector(VkVertexInputAttributeDescription, {
				{
					location = 0,
					binding = 0,
					format = vk.VK_FORMAT_R32G32B32_SFLOAT,
					offset = ffi.offsetof(Vertex, 'pos'),
				},
				{
					location = 1,
					binding = 0,
					format = vk.VK_FORMAT_R32G32B32_SFLOAT,
					offset = ffi.offsetof(Vertex, 'color'),
				},
				{
					location = 2,
					binding = 0,
					format = vk.VK_FORMAT_R32G32B32_SFLOAT,
					offset = ffi.offsetof(Vertex, 'texCoord'),
				},
			})
		end
	end,
}


local VulkanMesh = class()
VulkanMesh.Vertex = Vertex

function VulkanMesh:init(physDev, device, commandPool)
	local mesh = ObjLoader():load"viking_room.obj";

	local indices = mesh.triIndexes	-- vector'int32_t'
	asserteq(indices.type, ffi.typeof'int32_t') 	-- well, uint, but whatever
	-- copy from MeshVertex_t to Vertex ... TODO why bother ...
_G.vertices = vector(Vertex)
	vertices:resize(#mesh.vtxs)
	for i=0,#mesh.vtxs-1 do
		local srcv = mesh.vtxs.v[i]
		local dstv = vertices.v[i]
		dstv.pos = srcv.pos
		dstv.texCoord = srcv.texcoord	-- TODO y-flip?
		dstv.color:set(1, 1, 1)	-- do our objects have normal properties?  nope, just v vt vn ... why doesn't the demo use normals? does it bake lighting?
	end

	self.vertexBufferAndMemory = VulkanDeviceMemoryBuffer:makeBufferFromStaged(
		physDev,
		device.obj.id,
		commandPool,
		vertices.v,
		#vertices * ffi.sizeof(vertices.type)
	)

	self.numIndices = #indices
	self.indexBufferAndMemory = VulkanDeviceMemoryBuffer:makeBufferFromStaged(
		physDev,
		device.obj.id,
		commandPool,
		indices.v,
		#indices * ffi.sizeof(indices.type)
	)
end

return VulkanMesh
