#!/usr/bin/env luajit

-- [[ build shaders
local os = require 'ext.os'
local Targets = require 'make.targets'
local targets = Targets()
local fns = {
	{src='shader.vert', dst='shader-vert.spv'},
	{src='shader.frag', dst='shader-frag.spv'},
}
for _,fn in ipairs(fns) do
	targets:add{
		dsts = {fn.dst},
		srcs = {fn.src},
		rule = function(r)
			os.exec('glslangValidator -V "'..r.srcs[1]..'" -o "'..r.dsts[1]..'"')
		end,
	}
end
for _,fn in ipairs(fns) do
	targets:run(fn.dst)
end
--]]

-- [[ app
local ffi = require 'ffi'
local assert = require 'ext.assert'
local timer = require 'ext.timer'
local table = require 'ext.table'
local range = require 'ext.range'
local struct = require 'struct'
local matrix_ffi = require 'matrix.ffi'
local Image = require 'image'
local vk = require 'vk'
local VKCmdBuf = require 'vk.cmdbuf'
local VulkanMesh = require 'vk.vulkanmesh'


local uint64_t = ffi.typeof'uint64_t'
local uint32_t_1 = ffi.typeof'uint32_t[1]'


local UniformBufferObject = struct{
	name = 'UniformBufferObject',
	packed = true,
	fields = {
		{name = 'model', type = 'float[16]'},
		{name = 'view', type = 'float[16]'},
		{name = 'proj', type = 'float[16]'},
	},
}
assert.eq(ffi.sizeof(UniformBufferObject), ffi.sizeof'float' * 4 * 4 * 3)
local UniformBufferObject_ptr = ffi.typeof('$*', UniformBufferObject)



local VulkanApp = require 'vk.app':subclass()

VulkanApp.title = 'Vulkan test'
VulkanApp.maxFramesInFlight = 2

VulkanApp.vkenvArgs = {
	enableValidationLayers = true,
	title = VulkanApp.title,
}
function VulkanApp:initVK()
	VulkanApp.super.initVK(self)

	self.instance = self.vkenv.instance
	self.debug = self.vkenv.debug
	self.surface = self.vkenv.surface
	self.physDev = self.vkenv.physDev
	self.device = self.vkenv.device
	self.graphicsQueue = self.vkenv.graphicsQueue
	self.presentQueue = self.vkenv.presentQueue
	self.cmdPool = self.vkenv.cmdPool
	self.swapchain = self.vkenv.swapchain


	self.tmpMat = matrix_ffi({4,4}, 'float'):zeros()
	self.currentFrame = 0

	local args = {
		-- TODO ...
		shaders = {
			vertexFile = 'shader-vert.spv',
			fragmentFile = 'shader-frag.spv',
		},
		-- TODO shader bindings I guess ... sampler, etc
		-- TODO mesh geometry stuff too
		mesh = 'viking_room.obj',
		tex = 'viking_room.png',
	}


	local shaderStageFields = table{
		'vertex',
		'tessellationControl',
		'tessellationEvaluation',
		'geometry',
		'fragment',
		'compute',
	}
	local stageForField = {
		vertex = vk.VK_SHADER_STAGE_VERTEX_BIT,
		tessellationControl = vk.VK_SHADER_STAGE_TESSELLATION_CONTROL_BIT,
		tessellationEvaluation = vk.VK_SHADER_STAGE_TESSELLATION_EVALUATION_BIT,
		geometry = vk.VK_SHADER_STAGE_GEOMETRY_BIT,
		fragment = vk.VK_SHADER_STAGE_FRAGMENT_BIT,
		compute = vk.VK_SHADER_STAGE_COMPUTE_BIT,
	}


	-- map args.vertex|fragment|geometryCode|File to shaderModules.vertex|fragment|geometry
	self.shaderModules = {}
	if args.shaders then
		for _,k in ipairs(shaderStageFields) do
			local code = args.shaders[k..'Code']
			if not code then
				local fp = args.shaders[k..'File']
				if fp then
					code = assert(require 'ext.path'(fp):read())
				end
			end
			if code then
				self.shaderModules[k] = self.device:makeShader{
					code = code,
				}
			end
		end
	end

	-- TODO can you query this like you could in OpenGL?
	self.descriptorSetLayout = self.device:makeDescSetLayout{
		bindings = {
			-- must match the "layout(binding=0) uniform UniformBufferObject { ... }" in the vertex shader
			{
				binding = 0,
				descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
				descriptorCount = 1,
				stageFlags = vk.VK_SHADER_STAGE_VERTEX_BIT,
			},
			-- must match the "layout(binding=1) uniform sampler2D" in the fragment shader
			{
				binding = 1,
				descriptorType = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
				descriptorCount = 1,
				stageFlags = vk.VK_SHADER_STAGE_FRAGMENT_BIT,
			},
		},
	}
	self.pipelineLayout = self.device:makePipelineLayout{
		setLayouts = {
			self.descriptorSetLayout,
		},
	}

	local VulkanVertex = VulkanMesh.VulkanVertex
	self.pipeline = self.device:makePipeline{
		stages = shaderStageFields:mapi(function(field,_,t)
			local shader = self.shaderModules[field]
			if not shader then return end
			return {
				stage = stageForField[field],
				module = shader.id,
				pName = 'main',
			}, #t+1
		end),
		vertexInputState = {
			-- TODO this describes the buffer bound to the vertex data
			vertexBindingDescriptions = {
				{
					binding = 0,
					stride = ffi.sizeof(VulkanVertex),
					inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX,
				},
			},
			-- TODO this connects the vertex shader input locations
			--  with the vertex data offsets
			vertexAttributeDescriptions = {
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
				}
			},
		},
		inputAssemblyState = {
			topology = vk.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
		},
		viewportState = {
			viewportCount = 1,
			scissorCount = 1,
		},
		rasterizationState = {
			polygonMode = vk.VK_POLYGON_MODE_FILL,
			lineWidth = 1,
		},
		multisampleState = {
			rasterizationSamples = self.vkenv.msaaSamples,
		},
		depthStencilState = {
			depthTestEnable = vk.VK_TRUE,
			depthWriteEnable = vk.VK_TRUE,
			depthCompareOp = vk.VK_COMPARE_OP_LESS,
		},
		colorBlendState = {
			logicOp = vk.VK_LOGIC_OP_COPY,
			attachments = {
				{
					colorWriteMask = bit.bor(
						vk.VK_COLOR_COMPONENT_R_BIT,
						vk.VK_COLOR_COMPONENT_G_BIT,
						vk.VK_COLOR_COMPONENT_B_BIT,
						vk.VK_COLOR_COMPONENT_A_BIT
					)
				},
			},
		},
		dynamicState = {
			dynamicStates = {
				vk.VK_DYNAMIC_STATE_VIEWPORT,
				vk.VK_DYNAMIC_STATE_SCISSOR,
			},
		},
		layout = self.pipelineLayout.id,
		renderPass = self.swapchain.renderPass.id,
	}

	do
		local texturePath = args.tex
		local image = assert(Image(texturePath))
		image = image:rgba()
		assert.eq(image.channels, 4)
		
		local mipLevels = math.floor(math.log(math.max(image.width, image.height), 2)) + 1
		
		self.texture = self.device:makeImageFromStaged{
			extent = {
				width = image.width,
				height = image.height,
			},
			format = vk.VK_FORMAT_R8G8B8A8_SRGB,
			mipLevels = mipLevels,
			-- VkImageView:
			physDev = self.physDev,
			aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
			cmdPool = self.cmdPool,
			queue = self.graphicsQueue,
			-- TODO NOTICE setting this to false fails
			generateMipmap = true,
			size = image:getBufferSize(),
			data = image.buffer,
			-- is this staging-specific?
			samples = vk.VK_SAMPLE_COUNT_1_BIT,
			usage = bit.bor(
				vk.VK_IMAGE_USAGE_TRANSFER_SRC_BIT,
				vk.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
				vk.VK_IMAGE_USAGE_SAMPLED_BIT
			),	
		}

		self.textureSampler = self.device:makeSampler{
			magFilter = vk.VK_FILTER_LINEAR,
			minFilter = vk.VK_FILTER_LINEAR,
			mipmapMode = vk.VK_SAMPLER_MIPMAP_MODE_LINEAR,
			addressModeU = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT,
			addressModeV = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT,
			addressModeW = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT,
			anisotropyEnable = vk.VK_TRUE,
			maxAnisotropy = self.physDev:getProps().limits.maxSamplerAnisotropy,
			compareOp = vk.VK_COMPARE_OP_ALWAYS,
			maxLod = mipLevels,
			borderColor = vk.VK_BORDER_COLOR_INT_OPAQUE_BLACK,
		}
	end

	-- how to handle multiple meshes?
	-- do you really need one pipeline per mesh?
	self.mesh = VulkanMesh{
		physDev = self.physDev,
		device = self.device,
		cmdPool = self.cmdPool,
		queue = self.graphicsQueue,
		filename = args.mesh,
	}

	self.uniformBuffers = range(self.maxFramesInFlight):mapi(function(i)
		local size = ffi.sizeof(UniformBufferObject)
		local bm = self.device:makeBuffer{
			size = size,
			usage = vk.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
			physDev = self.physDev,
			memProps = bit.bor(
				vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
				vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
			),
		}
		return {
			bm = bm,
			mapped = bm.mem:map(size),
		}
	end)

	self.descriptorPool = self.device:makeDescPool{
		maxSets = self.maxFramesInFlight,
		poolSizes = {
			{
				type = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
				descriptorCount = self.maxFramesInFlight,
			},
			{
				type = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
				descriptorCount = self.maxFramesInFlight,
			},
		},
	}

	self.descriptorSets = range(self.maxFramesInFlight):mapi(function(i)
		return self.descriptorPool:makeDescSets{
			setLayout = self.descriptorSetLayout.id,
		}
	end)
	for i,descSet in ipairs(self.descriptorSets) do
		self.device:updateDescSets{
			{
				dstSet = descSet.id,
				dstBinding = 0,
				bufferInfo = {
					buffer = assert(self.uniformBuffers[i].bm.id),
					range = ffi.sizeof(UniformBufferObject),
				},
			},
			-- connect the uniform sampler2D with our bound texture
			{
				dstSet = descSet.id,
				dstBinding = 1,
				imageInfo = {
					sampler = self.textureSampler.id,
					imageView = self.texture.view.id,
					imageLayout = vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
				},
			}
		}
	end

	self.commandBuffers = range(self.maxFramesInFlight):mapi(function(i)
		return self.cmdPool:makeCmds{
			level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
		}
	end)

	self.imageAvailableSemaphores = range(self.maxFramesInFlight):mapi(function(i)
		return self.device:makeSemaphore()
	end)

	self.renderFinishedSemaphores = range(self.maxFramesInFlight):mapi(function(i)
		return self.device:makeSemaphore()
	end)

	self.inFlightFences = range(self.maxFramesInFlight):mapi(function(i)
		return self.device:makeFence{
			flags = vk.VK_FENCE_CREATE_SIGNALED_BIT,
		}
	end)


	-- structs used by update (so I don't have to realloc)
	
	self.imageIndex = uint32_t_1()
	self.acquireNextImageInfo = self.device.makeVkAcquireNextImageInfoKHR()
	self.cmdBufBeginInfo = VKCmdBuf.makeVkCommandBufferBeginInfo()
	self.cmdBufRenderPassBeginInfo = VKCmdBuf.makeVkRenderPassBeginInfo{
		clearValues = {
			{
				color = {
					float32 = {0,0,0,1},
				},
			},
			{
				depthStencil = {
					depth = 1,
					stencil = 0,
				},
			},
		},
	}
	self.viewports = VKCmdBuf.VkViewport{
		minDepth = 0,
		maxDepth = 1,
	}
	self.scissors = VKCmdBuf.VkRect2D()
	self.vertexBuffers = VKCmdBuf.VkBuffer_array(1,
		self.mesh.vertexBufferAndMemory.id
	)
	self.vertexOffsets = VKCmdBuf.VkDeviceSize_array(1, 0)
	self.submitInfo = self.graphicsQueue.makeVkSubmitInfo{
		waitDstStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
	}
	self.presentSwapchains = ffi.new'VkSwapchainKHR[1]'
	self.presentSwapchains[0] = assert(self.swapchain.obj.id)
	self.presentInfo = self.graphicsQueue.makeVkPresentInfoKHR{
		pSwapchains = self.presentSwapchains,
		swapchainCount = 1,
	}
end

function VulkanApp:update()
	assert(self.inFlightFences[1+self.currentFrame]:wait())

	local acquireNextImageInfo = self.acquireNextImageInfo
	--acquireNextImageInfo.pNext = nil
	acquireNextImageInfo.swapchain = self.swapchain.obj.id
	acquireNextImageInfo.timeout = ffi.cast(uint64_t, -1)
	acquireNextImageInfo.semaphore = self.imageAvailableSemaphores[1+self.currentFrame].id
	--acquireNextImageInfo.fence = nil
	acquireNextImageInfo.deviceMask = 1
	local _, _, result = self.device:acquireNextImage(self.acquireNextImageInfo, self.imageIndex)
	if result == vk.VK_ERROR_OUT_OF_DATE_KHR then
		self:recreateSwapchain()
		return
	elseif result ~= vk.VK_SUCCESS
	and result ~= vk.VK_SUBOPTIMAL_KHR
	then
		error("vkAcquireNextImage2KHR failed: "..tostring(result))
	end

	self:updateUniformBuffer()

	assert(self.inFlightFences[1+self.currentFrame]:reset())
	assert(self.commandBuffers[1+self.currentFrame]:reset())

	self:recordCommandBuffer(
		self.commandBuffers[1+self.currentFrame],
		self.imageIndex[0]
	)

	local submitInfo = self.submitInfo
	submitInfo.waitSemaphoreCount = 1
	submitInfo.pWaitSemaphores = self.imageAvailableSemaphores[1+self.currentFrame].idptr
	submitInfo.commandBufferCount = 1
	submitInfo.pCommandBuffers = self.commandBuffers[1+self.currentFrame].idptr
	submitInfo.signalSemaphoreCount = 1
	submitInfo.pSignalSemaphores = self.renderFinishedSemaphores[1+self.currentFrame].idptr
	assert(self.graphicsQueue:submit(submitInfo, nil, self.inFlightFences[1+self.currentFrame].id))

	-- TODO what's info.pResults vs the results returned from vkQueuePresentKHR ?
	local presentInfo = self.presentInfo
	presentInfo.waitSemaphoreCount = 1
	presentInfo.pWaitSemaphores = self.renderFinishedSemaphores[1+self.currentFrame].idptr
	presentInfo.pImageIndices = self.imageIndex
	local _, _, result = self.presentQueue:present(presentInfo)

	if result == vk.VK_ERROR_OUT_OF_DATE_KHR
	or result == vk.VK_SUBOPTIMAL_KHR
	or self.framebufferResized
	then
		self.framebufferResized = false
		self:recreateSwapchain()
	elseif result ~= vk.VK_SUCCESS then
		error("vkQueuePresentKHR failed: "..tostring(result))
	end

	self.currentFrame = (self.currentFrame + 1) % self.maxFramesInFlight
end

VulkanApp.startTime = timer.getTime()
function VulkanApp:updateUniformBuffer()
	local currentTime = timer.getTime()
	local time = currentTime - self.startTime

	local ar = tonumber(self.swapchain.extent.width) / tonumber(self.swapchain.extent.height)

	local ubo = ffi.cast(UniformBufferObject_ptr, self.uniformBuffers[self.currentFrame+1].mapped)
	-- really if I'm reassigning the underlying ptr then I just need one ...
	local m = self.tmpMat
	m.ptr = ubo.model
	m:setRotate(time * math.rad(90), 0, 0, 1)
--		:transpose4x4()
	m.ptr = ubo.view
	m:setLookAt(
		2,2,2,
		0,0,0,
		0,0,1
	)
--		:inv4x4()
--		:transpose4x4()
	m.ptr = ubo.proj
	m:setPerspective(45, ar, .1, 10)
		:applyScale(1,-1)	-- hmm why?
		:transpose4x4()
end

function VulkanApp:recordCommandBuffer(commandBuffer, imageIndex)
	-- TODO per vulkan api, if we just have null info, can we pass null?
	assert(commandBuffer:begin(self.cmdBufBeginInfo))

	local cmdBufRenderPassBeginInfo = self.cmdBufRenderPassBeginInfo
	cmdBufRenderPassBeginInfo.renderPass = self.swapchain.renderPass.id
	-- TODO how do we know the framebuffer index is less than the image from teh swapchain?
	-- framebufer[] is sized b imge of swapchain,
	-- but her it's indexed by maxFramesInFlight which is set to 2
	cmdBufRenderPassBeginInfo.framebuffer = self.swapchain.framebuffers[1+imageIndex].id
	cmdBufRenderPassBeginInfo.renderArea.extent = self.swapchain.extent
	commandBuffer:beginRenderPass(
		cmdBufRenderPassBeginInfo,
		vk.VK_SUBPASS_CONTENTS_INLINE
	)

	commandBuffer:bindPipeline(
		vk.VK_PIPELINE_BIND_POINT_GRAPHICS,
		self.pipeline.id
	)

	local viewports = self.viewports
	viewports.width = self.swapchain.extent.width
	viewports.height = self.swapchain.extent.height
	commandBuffer:setViewport(0, 1, viewports)

	local scissors = self.scissors
	scissors.extent.width = self.swapchain.extent.width
	scissors.extent.height = self.swapchain.extent.height
	commandBuffer:setScissors(0, 1, scissors)

	commandBuffer:bindVertexBuffers(
		0,
		1,
		self.vertexBuffers,
		self.vertexOffsets
	)

	commandBuffer:bindIndexBuffer(
		self.mesh.indexBufferAndMemory.id,
		0,
		vk.VK_INDEX_TYPE_UINT32
	)

	commandBuffer:bindDescriptorSets(
		vk.VK_PIPELINE_BIND_POINT_GRAPHICS,
		self.pipelineLayout.id,
		0,
		1,
		self.descriptorSets[1+self.currentFrame].idptr,
		0,
		nil
	)

	commandBuffer:drawIndexed(
		self.mesh.numIndices,
		1,
		0,
		0,
		0
	)

	commandBuffer:endRenderPass()
	assert(commandBuffer:done())
end

function VulkanApp:recreateSwapchain()
	if self.width == 0 or self.height == 0 then
		error "here"
	end
	assert(self.device:waitIdle())
	self.vkenv:resetSwapchain(self.width, self.height)
	self.swapchain = self.vkenv.swapchain
	self.presentSwapchains[0] = assert(self.swapchain.obj.id)
end

function VulkanApp:resize()
	self.framebufferResized = true
end

function VulkanApp:exit()
	if self.device then
		assert(self.device:waitIdle())
	end

	if self.imageAvailableSemaphores then
		for _,semaphore in ipairs(self.imageAvailableSemaphores) do
			semaphore:destroy()
		end
	end
	self.imageAvailableSemaphores = nil

	if self.renderFinishedSemaphores then
		for _,semaphore in ipairs(self.renderFinishedSemaphores) do
			semaphore:destroy()
		end
	end
	self.renderFinishedSemaphores = nil

	if self.inFlightFences then
		for _,fence in ipairs(self.inFlightFences) do
			fence:destroy()
		end
	end
	self.inFlightFences = nil

	if self.commandBuffers then
		for _,cmds in ipairs(self.commandBuffers) do
			cmds:destroy()
		end
	end
	self.commandBuffers = nil

	--[[ gives "descriptorPool must have been created with the VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT flag"
	if self.descriptorSets then
		self.descriptorSets:destroy()
	end
	--]]
	self.descriptorSets = nil

	if self.textureSampler then
		self.textureSampler:destroy()
	end
	self.textureSampler = nil

	if self.texture then
		self.texture:destroy()
	end
	self.texture = nil

	if self.uniformBuffers then
		for _,ub in ipairs(self.uniformBuffers) do
			ub.bm:destroy()
		end
	end
	self.uniformBuffers = nil

	if self.descriptorPool then
		self.descriptorPool:destroy()
	end
	self.descriptorPool = nil

	if self.mesh then
		self.mesh:destroy()
	end
	self.mesh = nil

	-- [[ graphics pipeline related
	if self.descriptorSetLayout then
		self.descriptorSetLayout:destroy()
	end
	self.descriptorSetLayout = nil

	if self.pipelineLayout then
		self.pipelineLayout:destroy()
	end
	self.pipelineLayout = nil

	if self.shaderModules then
		for _,shader in pairs(self.shaderModules) do
			shader:destroy()
		end
	end
	self.shaderModules = nil

	if self.pipeline then
		self.pipeline:destroy()
	end
	self.pipeline = nil
	--]]

	VulkanApp.super.exit(self)
end

return VulkanApp():run()
--]]
