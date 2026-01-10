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
			local result = ffi.new(VkVertexInputBindingDescription, {
				binding = 0,
				stride = ffi.sizeof(VulkanVertex),
				inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX,
			})
_G.VertexRetainBiningDescription = result			
			return result
		end

		mt.getAttributeDescriptions = function()
			local result = vector(VkVertexInputAttributeDescription, {
				{
					location = 0,
					binding = 0,
					format = vk.VK_FORMAT_R32G32B32_SFLOAT,
					offset = ffi.offsetof(VulkanVertex, 'pos'),
				},
				{
					location = 1,
					binding = 0,
					format = vk.VK_FORMAT_R32G32B32_SFLOAT,
					offset = ffi.offsetof(VulkanVertex, 'color'),
				},
				{
					location = 2,
					binding = 0,
					format = vk.VK_FORMAT_R32G32B32_SFLOAT,
					offset = ffi.offsetof(VulkanVertex, 'texCoord'),
				},
			})
_G.VertexRetainAttributeDescriptions = result			
			return result
		end
	end,
}


local VulkanMesh = class()
VulkanMesh.VulkanVertex = VulkanVertex

function VulkanMesh:init(physDev, device, commandPool)
	self.mesh = ObjLoader():load"viking_room.obj";

	self.indices = self.mesh.triIndexes	-- vector'int32_t'
	asserteq(self.indices.type, ffi.typeof'int32_t') 	-- well, uint, but whatever
	-- copy from MeshVertex_t to VulkanVertex ... TODO why bother ...
	self.vertices = vector(VulkanVertex)
	self.vertices:resize(#self.mesh.vtxs)
	for i=0,#self.mesh.vtxs-1 do
		local srcv = self.mesh.vtxs.v[i]
		local dstv = self.vertices.v[i]
		dstv.pos = srcv.pos
		dstv.texCoord = srcv.texcoord	-- TODO y-flip?
		dstv.color:set(1, 1, 1)	-- do our objects have normal properties?  nope, just v vt vn ... why doesn't the demo use normals? does it bake lighting?
	end

	self.vertexBufferAndMemory = VulkanDeviceMemoryBuffer:makeBufferFromStaged(
		physDev,
		device.obj.id,
		commandPool,
		self.vertices.v,
		#self.vertices * ffi.sizeof(self.vertices.type)
	)

	self.numIndices = #self.indices
	self.indexBufferAndMemory = VulkanDeviceMemoryBuffer:makeBufferFromStaged(
		physDev,
		device.obj.id,
		commandPool,
		self.indices.v,
		#self.indices * ffi.sizeof(self.indices.type)
	)

	self.vertices = nil
	self.indices = nil
	self.mesh = nil
end

return VulkanMesh
