-- this isn't a wrapper class to the Vk classes
-- it's just a helper, and itself wraps 'mesh.objloader'
local ffi = require 'ffi'
local class = require 'ext.class'
local asserteq = require 'ext.assert'.eq
local vector = require 'ffi.cpp.vector-lua'
local ObjLoader = require 'mesh.objloader'
local VulkanDeviceMemoryBuffer = require 'vk.vulkandevicememorybuffer'


local VulkanMesh = class()

function VulkanMesh:init(physDev, device, commandPool)
	local mesh = ObjLoader():load"viking_room.obj";

	local indices = mesh.triIndexes	-- vector'int32_t'
	asserteq(indices.type, ffi.typeof'int32_t') 	-- well, uint, but whatever
	-- copy from MeshVertex_t to Vertex ... TODO why bother ...
	local vertices = vector'Vertex'
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
