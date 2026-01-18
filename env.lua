--[[
helper
TODO rename to VKEnv and make this like cl.env
to just init one device, physdev, etc 
and then use this for the other vulkan-helper stuff so I don't have to pass around so many different args
--]]
local ffi = require 'ffi'
local assert = require 'ext.assert'
local class = require 'ext.class'
local table = require 'ext.table'
local range = require 'ext.range'
local timer = require 'ext.timer'
local struct = require 'struct'
local matrix_ffi = require 'matrix.ffi'
local Image = require 'image'
local vk = require 'vk'
local VKInstance = require 'vk.instance'
local VKSurface = require 'vk.surface'
local VKPhysDev = require 'vk.physdev'
local VKDevice = require 'vk.device'
local VKQueue = require 'vk.queue'
local VKDescriptorSetLayout = require 'vk.descriptorsetlayout'
local VKPipelineLayout = require 'vk.pipelinelayout'
local VKShaderModule = require 'vk.shadermodule'
local VKPipeline = require 'vk.pipeline'
local VKCommandPool = require 'vk.commandpool'
local VKCommandBuffer = require 'vk.commandbuffer'
local VKDebugUtilsMessenger = require 'vk.debugutilsmessenger'
local VKSampler = require 'vk.sampler'
local VKDescriptorPool = require 'vk.descriptorpool'
local VKSemaphore = require 'vk.semaphore'
local VKFence = require 'vk.fence'
local VKBuffer = require 'vk.buffer'


local VulkanDeviceMemoryImage = require 'vk.vulkandevicememoryimage'
local VulkanSwapchain = require 'vk.vulkanswapchain'
local VulkanMesh = require 'vk.vulkanmesh'

local float = ffi.typeof'float'
local uint32_t_1 = ffi.typeof'uint32_t[1]'
local uint64_t = ffi.typeof'uint64_t'


local UniformBufferObject = struct{
	name = 'UniformBufferObject',
	packed = true,
	fields = {
		{name = 'model', type = 'float[16]'},
		{name = 'view', type = 'float[16]'},
		{name = 'proj', type = 'float[16]'},
	},
}
assert.eq(ffi.sizeof(UniformBufferObject), ffi.sizeof(float) * 4 * 4 * 3)
local UniformBufferObject_ptr = ffi.typeof('$*', UniformBufferObject)


local validationLayerNames = {
	'VK_LAYER_KHRONOS_validation'
}


-- but why not just use bitfields? meh
local function VK_MAKE_VERSION(major, minor, patch)
	return bit.bor(bit.lshift(major, 22), bit.lshift(minor, 12), patch)
end
local function VK_MAKE_API_VERSION(variant, major, minor, patch)
	return bit.bor(bit.lshift(variant, 29), bit.lshift(major, 22), bit.lshift(minor, 12), patch)
end
local VK_API_VERISON_1_0 = VK_MAKE_API_VERSION(0, 1, 0, 0)


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

local VKEnv = class()

VKEnv.enableValidationLayers = false
VKEnv.maxFramesInFlight = 2

function VKEnv:init(args)
	local app = assert(args.app)
	self.enableValidationLayers = args.enableValidationLayers 
	self.maxFramesInFlight = args.maxFramesInFlight
	self.app = app

	self.framebufferResized = false
	self.currentFrame = 0

	self.tmpMat = matrix_ffi({4,4}, float):zeros()

	local enabledLayers = table()
	do
		local layerProps = VKInstance:getLayerProps()
--DEBUG:print'vulkan layers:'
--DEBUG:for _,layerProp in ipairs(layerProps) do
--DEBUG:	print('',layerProp.layerName, layerProp.description)
--DEBUG:end

		local enabledExtensions = VKInstance:getExts()

--DEBUG:print'vulkan enabledExtensions:'
--DEBUG:for _,s in ipairs(enabledExtensions) do
--DEBUG:	print('', s)
--DEBUG:end

		if self.enableValidationLayers then
			for _,layerName in ipairs(validationLayerNames) do
				if not layerProps:find(nil, function(layerProp) return layerProp.layerName == layerName end) then
					error("validation layer "..layerName.." requested, but not available!")
				end
			end

			enabledExtensions:insert'VK_EXT_debug_utils'
			enabledLayers:append(validationLayerNames)
		end

		self.instance = VKInstance{
			applicationInfo = {
				pApplicationName = app.title,
				applicationVersion = VK_MAKE_API_VERSION(0, 1, 0, 0),
				pEngineName = 'no engine',
				engineVersion = VK_MAKE_API_VERSION(0, 1, 0, 0),
				apiVersion = VK_API_VERISON_1_0,
			},
			enabledLayers = enabledLayers,
			enabledExtensions = enabledExtensions,
		}
	end

	-- debug:
	if self.enableValidationLayers then
		self.debug = VKDebugUtilsMessenger{
			instance = self.instance,
			messageSeverity = bit.bor(
				vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT,
				--vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT,
				vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT,
				vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT
			),
			messageType = bit.bor(
				vk.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT,
				vk.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT,
				vk.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT
				--vk.VK_DEBUG_UTILS_MESSAGE_TYPE_DEVICE_ADDRESS_BINDING_BIT_EXT
			),
			userCallback = function(
				messageSeverity,	-- VkDebugUtilsMessageSeverityFlagBitsEXT
				messageTypes,		-- VkDebugUtilsMessageTypeFlagsEXT
				pCallbackData,		-- const VkDebugUtilsMessengerCallbackDataEXT*
				pUserData			-- void*
			) -- returns VkBool32
				-- this is run on the same thread? or no?
				io.stderr:write("validation layer: ", ffi.string(pCallbackData.pMessage), '\n')
				return vk.VK_FALSE
			end,
		}
	end

	self.surface = VKSurface{
		window = app.window,
		instance = self.instance,
	}

--DEBUG:print'devices:'
--DEBUG:for _,physDev in ipairs(self.instance:getPhysDevs()) do
--DEBUG:	local props = physDev:getProps()
--DEBUG:	print('',
--DEBUG:		ffi.string(props.deviceName)
--DEBUG:		..' type='..tostring(props.deviceType)
--DEBUG:	)
--DEBUG:end

	local deviceExtensions = table{
		'VK_KHR_swapchain',
	}

	self.physDev = assert(select(2, self.instance
		:getPhysDevs()
		:find(nil, function(physDev)
			return physDev:isDeviceSuitable(self.surface, deviceExtensions)
		end)),
		"failed to find a suitable GPU")

	self.msaaSamples = self.physDev:getMaxUsableSampleCount()
--DEBUG:print('msaaSamples', self.msaaSamples)

	do
		local indices = self.physDev:findQueueFamilies(self.surface)
		
		self.device = VKDevice{
			physDev = self.physDev,
			queueCreateInfos = table.keys{
				[indices.graphicsFamily] = true,
				[indices.presentFamily] = true,
			}:mapi(function(queueFamily)
				return {
					queueFamilyIndex = queueFamily,
					queuePriorities = {1},
				}
			end),
			enabledLayers = enabledLayers,
			enabledExtensions = deviceExtensions,
			enabledFeatures = {
				samplerAnisotropy = vk.VK_TRUE,
			},
		}

		self.graphicsQueue = VKQueue{
			device = self.device,
			family = indices.graphicsFamily,
		}

		self.presentQueue = VKQueue{
			device = self.device,
			family = indices.presentFamily,
		}
	end

	self:resetSwapchain()

	self.commandPool = VKCommandPool{
		device = self.device,
		flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
		queueFamilyIndex = assert.index(self.physDev:findQueueFamilies(self.surface), 'graphicsFamily'),
	}


	-- app-specific init:
	-- graphics pipeline related:

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
				self.shaderModules[k] = VKShaderModule{
					device = self.device.id,
					code = code,
				}
			end
		end
	end

	-- TODO can you query this like you could in OpenGL?
	self.descriptorSetLayout = VKDescriptorSetLayout{
		device = self.device.id,
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
	self.pipelineLayout = VKPipelineLayout{
		device = self.device.id,
		setLayouts = {
			self.descriptorSetLayout,
		},
	}

	local VulkanVertex = VulkanMesh.VulkanVertex
	self.pipeline = VKPipeline{
		device = self.device.id,
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
			rasterizationSamples = self.msaaSamples,
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
		
		self.textureImageAndMemory = VulkanDeviceMemoryImage:makeTextureFromStagedAndView{
			physDev = self.physDev,
			device = self.device.id,
			commandPool = self.commandPool,
			queue = self.graphicsQueue,
			srcBuffer = image.buffer,
			bufferSize = image:getBufferSize(),
			width = image.width,
			height = image.height,
			format = vk.VK_FORMAT_R8G8B8A8_SRGB,
			mipLevels = mipLevels,
			generateMipmap = true,
			-- VkImageView:
			aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
		}

		self.textureSampler = VKSampler{
			device = self.device,
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
		commandPool = self.commandPool,
		queue = self.graphicsQueue,
		filename = args.mesh,
	}

	self.uniformBuffers = range(self.maxFramesInFlight):mapi(function(i)
		local size = ffi.sizeof(UniformBufferObject)
		local bm = VKBuffer{
			device = self.device.id,
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

	self.descriptorPool = VKDescriptorPool{
		device = self.device,
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
					imageView = self.textureImageAndMemory.imageView.id,
					imageLayout = vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
				},
			}
		}
	end

	self.commandBuffers = range(self.maxFramesInFlight):mapi(function(i)
		return self.commandPool:makeCmds{
			level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
		}
	end)

	self.imageAvailableSemaphores = range(self.maxFramesInFlight):mapi(function(i)
		return VKSemaphore{
			device = self.device,
		}
	end)

	self.renderFinishedSemaphores = range(self.maxFramesInFlight):mapi(function(i)
		return VKSemaphore{
			device = self.device,
		}
	end)

	self.inFlightFences = range(self.maxFramesInFlight):mapi(function(i)
		return VKFence{
			device = self.device,
			flags = vk.VK_FENCE_CREATE_SIGNALED_BIT,
		}
	end)

	-- structs used by drawFrame (so I don't have to realloc)
	self.imageIndex = uint32_t_1()
	self.acquireNextImageInfo = VKDevice.makeVkAcquireNextImageInfoKHR()
	self.cmdBufBeginInfo = VKCommandBuffer.makeVkCommandBufferBeginInfo()
	self.cmdBufRenderPassBeginInfo = VKCommandBuffer.makeVkRenderPassBeginInfo{
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
	self.viewports = VKCommandBuffer.VkViewport{
		minDepth = 0,
		maxDepth = 1,
	}
	self.scissors = VKCommandBuffer.VkRect2D()
	self.vertexBuffers = VKCommandBuffer.VkBuffer_array(1,
		self.mesh.vertexBufferAndMemory.id
	)
	self.vertexOffsets = VKCommandBuffer.VkDeviceSize_array(1, 0)
	self.submitInfo = VKQueue.makeVkSubmitInfo{
		waitDstStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
	}
	self.presentInfo = VKQueue.makeVkPresentInfoKHR{
		swapchains = {self.swapchain},
	}
end

function VKEnv:resetSwapchain()
	self.swapchain = VulkanSwapchain{
		width = self.app.width,
		height = self.app.height,
		physDev = self.physDev,
		device = self.device,
		surface = self.surface,
		samples = self.msaaSamples,
	}
end

function VKEnv:drawFrame()
-- right here once all the first set of frames are exhausted, this stalls indefinitely
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

VKEnv.startTime = timer.getTime()
function VKEnv:updateUniformBuffer()
	local app = self.app
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

function VKEnv:recordCommandBuffer(commandBuffer, imageIndex)
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

function VKEnv:recreateSwapchain()
	local app = self.app
	if app.width == 0 or app.height == 0 then
		error "here"
	end
	assert(self.device:waitIdle())
	self.swapchain.obj:destroy()
	self:resetSwapchain()
end

function VKEnv:exit()
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

	if self.textureImageAndMemory then
		self.textureImageAndMemory:destroy()
	end
	self.textureImageAndMemory = nil

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

	if self.commandPool then
		self.commandPool:destroy()
	end
	self.commandPool = nil

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

	if self.swapchain then
		self.swapchain:destroy()
	end
	self.swapchain = nil

	if self.device then
		self.device:destroy()
	end
	self.device = nil

	if self.surface then
		self.surface:destroy()
	end
	self.surface = nil

	if self.debug then
		self.debug:destroy()
	end
	self.debug = nil

	if self.instance then
		self.instance:destroy()
	end
	self.instance = nil
end

return VKEnv
