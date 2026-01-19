-- this isn't a wrapper class to the Vk classes
-- it's just a helper, and itself wraps 'mesh.objloader'
local ffi = require 'ffi'
local class = require 'ext.class'
local asserteq = require 'ext.assert'.eq
local vec3f = require 'vec-ffi.vec3f'
local struct = require 'struct'
local vector = require 'ffi.cpp.vector-lua'
local ObjLoader = require 'mesh.objloader'
local vk = require 'vk'
local VKBuffer = require 'vk.buffer'


local VulkanVertex
VulkanVertex = struct{
	name = 'VulkanVertex',
	fields = {
		{name = 'pos', type = 'vec3f_t'},
		{name = 'color', type = 'vec3f_t'},
		{name = 'texCoord', type = 'vec3f_t'},
	},
}


local VulkanMesh = class()
VulkanMesh.VulkanVertex = VulkanVertex

function VulkanMesh:init(args)
	local device = args.device

	local mesh = ObjLoader():load(args.filename)

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

	self.vertexBufferAndMemory = device:makeBufferFromStaged{
		physDev = args.physDev,
		cmdPool = args.cmdPool,
		queue = args.queue,
		data = vertices.v,
		size = vertices:getNumBytes(),
		usage = bit.bor(
			vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
			vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT
		),
	}

	self.numIndices = #indices
	self.indexBufferAndMemory = device:makeBufferFromStaged{
		physDev = args.physDev,
		cmdPool = args.cmdPool,
		queue = args.queue,
		data = indices.v,
		size = indices:getNumBytes(),
		usage = bit.bor(
			vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
			vk.VK_BUFFER_USAGE_INDEX_BUFFER_BIT
		),
	}
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
