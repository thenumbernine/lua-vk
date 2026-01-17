--helper
local ffi = require 'ffi'
local assert = require 'ext.assert'
local class = require 'ext.class'
local table = require 'ext.table'
local range = require 'ext.range'
local timer = require 'ext.timer'
local struct = require 'struct'
local matrix_ffi = require 'matrix.ffi'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGetVector = require 'vk.util'.vkGetVector
local makeStructCtor = require 'vk.util'.makeStructCtor
local VKSurface = require 'vk.surface'
local VKQueue = require 'vk.queue'
local VKDebugUtilsMessenger = require 'vk.debugutilsmessenger'
local VKSampler = require 'vk.sampler'
local VKDescriptorPool = require 'vk.descriptorpool'
local VKSemaphore = require 'vk.semaphore'
local VKFence = require 'vk.fence'
require 'ffi.req' 'c.string'	-- debug: strcmp
require 'ffi.req' 'c.stdio'		-- debug: fprintf(stderr, ...)


local VulkanInstance = require 'vk.vulkaninstance'
local VulkanPhysicalDevice = require 'vk.vulkanphysdev'
local VulkanDevice = require 'vk.vulkandevice'
local VulkanDeviceMemoryImage = require 'vk.vulkandevicememoryimage'
local VulkanSwapchain = require 'vk.vulkanswapchain'
local VulkanGraphicsPipeline = require 'vk.vulkangraphicspipeline'
local VulkanCommandPool = require 'vk.vulkancommandpool'
local VulkanDeviceMemoryBuffer = require 'vk.vulkandevicememorybuffer'
local VulkanBufferMemoryAndMapped = require 'vk.vulkanbuffermemoryandmapped'
local VulkanMesh = require 'vk.vulkanmesh'

local float = ffi.typeof'float'
local uint32_t_1 = ffi.typeof'uint32_t[1]'
local uint64_t = ffi.typeof'uint64_t'
local VkDescriptorBufferInfo = ffi.typeof'VkDescriptorBufferInfo'
local VkDescriptorImageInfo = ffi.typeof'VkDescriptorImageInfo'
local VkLayerProperties = ffi.typeof'VkLayerProperties'
local VkWriteDescriptorSet_array = ffi.typeof'VkWriteDescriptorSet[?]'


local makeVkWriteDescriptorSet = makeStructCtor'VkWriteDescriptorSet'

local makeVkAcquireNextImageInfoKHR = makeStructCtor'VkAcquireNextImageInfoKHR'

local makeVkSubmitInfo = VKQueue.makeVkSubmitInfo
local makeVkPresentInfoKHR = VKQueue.makeVkPresentInfoKHR


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

local VulkanCommon = class()

VulkanCommon.enableValidationLayers = true
VulkanCommon.maxFramesInFlight = 2

function VulkanCommon:init(app)
	self.app = assert(app)
	self.framebufferResized = false
	self.currentFrame = 0

	self.modelMat = matrix_ffi({4,4}, float):zeros()
	self.viewMat = matrix_ffi({4,4}, float):zeros()
	self.projMat = matrix_ffi({4,4}, float):zeros()

	assert(not self.enableValidationLayers or self:checkValidationLayerSupport(), "validation layers requested, but not available!")
	self.instance = VulkanInstance(self)

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
				ffi.C.fprintf(ffi.C.stderr, "validation layer: %s\n", pCallbackData.pMessage)
				return vk.VK_FALSE
			end,
		}
	end

	self.surface = VKSurface{
		window = app.window,
		instance = self.instance.obj,
	}

	local deviceExtensions = table()
	deviceExtensions:insert'VK_KHR_swapchain'

	self.physDev = VulkanPhysicalDevice(self, deviceExtensions)

	self.msaaSamples = self.physDev:getMaxUsableSampleCount()
print('msaaSamples', self.msaaSamples)

	do
		local indices = self.physDev:findQueueFamilies(nil, self.surface)
		self.device = VulkanDevice(
			self.physDev.obj,
			deviceExtensions,
			self.enableValidationLayers and validationLayerNames or nil,
			indices
		)
		self.graphicsQueue = VKQueue{
			device = self.device.obj,
			family = indices.graphicsFamily,
		}
		self.presentQueue = VKQueue{
			device = self.device.obj,
			family = indices.presentFamily,
		}
	end

	self:createSwapchain()

	self.graphicsPipeline = VulkanGraphicsPipeline(self.physDev, self.device.obj.id, self.swapchain.renderPass.id, self.msaaSamples)

	self.commandPool = VulkanCommandPool(self, self.physDev, self.device, self.surface)

	self.textureImageAndMemory = self:createTextureImage()
	self.textureImageView = self.swapchain:createImageView(
		self.device.obj.id,
		self.textureImageAndMemory.image.id,
		vk.VK_FORMAT_R8G8B8A8_SRGB,
		vk.VK_IMAGE_ASPECT_COLOR_BIT,
		self.mipLevels
	)

	self.textureSampler = VKSampler{
		device = self.device,
		magFilter = vk.VK_FILTER_LINEAR,
		minFilter = vk.VK_FILTER_LINEAR,
		mipmapMode = vk.VK_SAMPLER_MIPMAP_MODE_LINEAR,
		addressModeU = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT,
		addressModeV = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT,
		addressModeW = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT,
		anisotropyEnable = vk.VK_TRUE,
		maxAnisotropy = self.physDev.obj:getProps().limits.maxSamplerAnisotropy,
		compareEnable = vk.VK_FALSE,
		compareOp = vk.VK_COMPARE_OP_ALWAYS,
		minLod = 0,
		maxLod = self.mipLevels,
		borderColor = vk.VK_BORDER_COLOR_INT_OPAQUE_BLACK,
		unnormalizedCoordinates = vk.VK_FALSE,
	}

	self.mesh = VulkanMesh(self.physDev, self.device, self.commandPool)
	self.uniformBuffers = range(self.maxFramesInFlight):mapi(function(i)
		local size = ffi.sizeof(UniformBufferObject)
		local bm = VulkanDeviceMemoryBuffer(
			self.physDev,
			self.device.obj.id,
			size,
			vk.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
			bit.bor(
				vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
				vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
			)
		)
		return VulkanBufferMemoryAndMapped(
			bm,
			bm.memory:map(size)
		)
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

	self.descriptorSets = self:createDescriptorSets()

	self.commandBuffers = range(self.maxFramesInFlight):mapi(function(i)
		return self.commandPool.obj:makeCmds{
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
	self.acquireNextImageInfo = makeVkAcquireNextImageInfoKHR()
	self.submitInfo = makeVkSubmitInfo{
		waitDstStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
	}
	self.presentInfo = makeVkPresentInfoKHR{
		swapchains = {self.swapchain},
	}
end

function VulkanCommon:checkValidationLayerSupport()
	local availableLayers = vkGetVector(VkLayerProperties, vkassert, vk.vkEnumerateInstanceLayerProperties)
	local layerName = validationLayerNames[1]
	for i=0,#availableLayers-1 do
		local layerProperties = availableLayers.v + i
		-- hmm, why does vulkan hpp use array<char> instead of string?
		if 0 == ffi.C.strcmp(layerName, layerProperties.layerName) then
			return true
		end
	end
	return false
end

function VulkanCommon:createSwapchain()
	local app = self.app
	self.swapchain = VulkanSwapchain(
		app.width,
		app.height,
		self.physDev,
		self.device.obj,
		self.surface,
		self.msaaSamples)
end

function VulkanCommon:createTextureImage()
	local texturePath = 'viking_room.png'
	local Image = require 'image'
	local image = assert(Image(texturePath))
	image = image:setChannels(4)
	assert(image.channels == 4)	-- TODO setChannels
	local bufferSize = image.width * image.height * image.channels

	-- TODO why store in 'self', why not store with 'textureImageAndMemory' and 'textureImageView' all in one place?
	self.mipLevels = math.floor(math.log(math.max(image.width, image.height), 2)) + 1
	local textureImageAndMemory = VulkanDeviceMemoryImage:makeTextureFromStaged(
		self.physDev,
		self.device.obj.id,
		self.commandPool,
		image.buffer,
		bufferSize,
		image.width,
		image.height,
		self.mipLevels
	)

	self:generateMipmaps(
		textureImageAndMemory.image.id,
		vk.VK_FORMAT_R8G8B8A8_SRGB,
		image.width,
		image.height,
		self.mipLevels
	)

	return textureImageAndMemory
end

function VulkanCommon:generateMipmaps(image, imageFormat, texWidth, texHeight, mipLevels)
	local formatProperties = self.physDev.obj:getFormatProps(imageFormat)

	if 0 == bit.band(formatProperties.optimalTilingFeatures, vk.VK_FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_LINEAR_BIT) then
		error "texture image format does not support linear blitting!"
	end

	self.graphicsQueue:singleTimeCommand(
		self.commandPool.obj,
		function(commandBuffer)
			local barrier = commandBuffer.makeVkImageMemoryBarrier{
				srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED,
				dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED,
				image = image,
				subresourceRange = {
					aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
					levelCount = 1,
					layerCount = 1,
				},
			}

			local mipWidth = texWidth
			local mipHeight = texHeight

			for i=1,mipLevels-1 do
				barrier.subresourceRange.baseMipLevel = i - 1
				barrier.oldLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
				barrier.newLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL
				barrier.srcAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT
				barrier.dstAccessMask = vk.VK_ACCESS_TRANSFER_READ_BIT
				commandBuffer:pipelineBarrier(
					vk.VK_PIPELINE_STAGE_TRANSFER_BIT,  -- srcStageMask
					vk.VK_PIPELINE_STAGE_TRANSFER_BIT,	-- dstStageMask
					0,									-- dependencyFlags
					0,									-- memoryBarrierCount
					nil,								-- pMemoryBarriers
					0,									-- bufferMemoryBarrierCount
					nil,								-- pBufferMemoryBarriers
					1,									-- imageMemoryBarrierCount
					barrier								-- pImageMemoryBarriers
				)

				commandBuffer:blitImage(
					image,
					vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
					image,
					vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
					1,
					commandBuffer.VkImageBlit{
						srcSubresource = {
							aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
							mipLevel = i-1,
							layerCount = 1,
						},
						srcOffsets = {
							{x=0, y=0, z=0},
							{x=mipWidth, y=mipHeight, z=1},
						},
						dstSubresource = {
							aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
							mipLevel = i,
							layerCount = 1,
						},
						dstOffsets = {
							{x=0, y=0, z=0},
							{
								x = mipWidth > 1 and bit.rshift(mipWidth, 1) or 1,
								y = mipHeight > 1 and bit.rshift(mipHeight, 1) or 1,
								z = 1,
							},
						},
					},
					vk.VK_FILTER_LINEAR
				)

				barrier.oldLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL
				barrier.newLayout = vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
				barrier.srcAccessMask = vk.VK_ACCESS_TRANSFER_READ_BIT
				barrier.dstAccessMask = vk.VK_ACCESS_SHADER_READ_BIT
				commandBuffer:pipelineBarrier(
					vk.VK_PIPELINE_STAGE_TRANSFER_BIT,  		-- srcStageMask
					vk.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,   -- dstStageMask
					0,											-- dependencyFlags
					0,											-- memoryBarrierCount
					nil,										-- pMemoryBarriers
					0,											-- bufferMemoryBarrierCount
					nil,										-- pBufferMemoryBarriers
					1,											-- imageMemoryBarrierCount
					barrier										-- pImageMemoryBarriers
				)

				if mipWidth > 1 then mipWidth = bit.rshift(mipWidth, 1) end
				if mipHeight > 1 then mipHeight = bit.rshift(mipHeight, 1) end
			end

			barrier.subresourceRange.baseMipLevel = mipLevels - 1;
			barrier.oldLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
			barrier.newLayout = vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
			barrier.srcAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT
			barrier.dstAccessMask = vk.VK_ACCESS_SHADER_READ_BIT

			commandBuffer:pipelineBarrier(
				vk.VK_PIPELINE_STAGE_TRANSFER_BIT,  		-- srcStageMask
				vk.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,   -- dstStageMask
				0,											-- dependencyFlags
				0,											-- memoryBarrierCount
				nil,										-- pMemoryBarriers
				0,											-- bufferMemoryBarrierCount
				nil,										-- pBufferMemoryBarriers
				1,											-- imageMemoryBarrierCount
				barrier										-- pImageMemoryBarriers
			)
		end
	)
end

function VulkanCommon:createDescriptorSets()
	local descriptorSets = self.descriptorPool:makeDescSets{
		setLayouts = range(self.maxFramesInFlight):mapi(function(i)
			return self.graphicsPipeline.descriptorSetLayout.id
		end),
	}

	for i=0,self.maxFramesInFlight-1 do
		local numDescriptorWrites = 2
		local descriptorWrites = VkWriteDescriptorSet_array(numDescriptorWrites, {
			makeVkWriteDescriptorSet{
				dstSet = descriptorSets.idptr[i],
				dstBinding = 0,
				descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
				descriptorCount = 1,
				pBufferInfo = VkDescriptorBufferInfo{
					buffer = assert(self.uniformBuffers[i+1].bm.buffer.id),
					range = ffi.sizeof(UniformBufferObject),
				},
			},
			makeVkWriteDescriptorSet{
				dstSet = descriptorSets.idptr[i],
				dstBinding = 1,
				descriptorType = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
				descriptorCount = 1,
				pImageInfo = VkDescriptorImageInfo{
					sampler = self.textureSampler.id,
					imageView = self.textureImageView.id,
					imageLayout = vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
				},
			}
		})
		vk.vkUpdateDescriptorSets(
			self.device.obj.id,
			-- TODO use the same array conversion function in makeStructCtor
			numDescriptorWrites,
			descriptorWrites,
			0,
			nil
		)
	end

	return descriptorSets
end

function VulkanCommon:setFramebufferResized()
	self.framebufferResized = true
end

function VulkanCommon:drawFrame()
-- right here once all the first set of frames are exhausted, this stalls indefinitely
	assert(self.inFlightFences[1+self.currentFrame]:wait())

	local acquireNextImageInfo = self.acquireNextImageInfo
	--acquireNextImageInfo.pNext = nil
	acquireNextImageInfo.swapchain = self.swapchain.obj.id
	acquireNextImageInfo.timeout = ffi.cast(uint64_t, -1)
	acquireNextImageInfo.semaphore = self.imageAvailableSemaphores[1+self.currentFrame].id
	--acquireNextImageInfo.fence = nil
	acquireNextImageInfo.deviceMask = 1
	local result = vk.vkAcquireNextImage2KHR(
		self.device.obj.id,
		self.acquireNextImageInfo,
		self.imageIndex
	)
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
	-- don't use conversion field, just use the pointer
	submitInfo.waitSemaphoreCount = 1
	submitInfo.pWaitSemaphores = self.imageAvailableSemaphores[1+self.currentFrame].idptr
	-- don't use conversion field, just use the pointer
	submitInfo.commandBufferCount = 1
	submitInfo.pCommandBuffers = self.commandBuffers[1+self.currentFrame].idptr
	-- don't use conversion field, just use the pointer
	submitInfo.signalSemaphoreCount = 1
	submitInfo.pSignalSemaphores = self.renderFinishedSemaphores[1+self.currentFrame].idptr

	assert(self.graphicsQueue:submit(submitInfo, nil, self.inFlightFences[1+self.currentFrame].id))

	-- TODO what's info.pResults vs the results returned from vkQueuePresentKHR ?
	local presentInfo = self.presentInfo
	-- don't use conversion field, just use the pointer
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

VulkanCommon.startTime = timer.getTime()
function VulkanCommon:updateUniformBuffer()
	local app = self.app
	local currentTime = timer.getTime()
	local time = currentTime - self.startTime

	local ar = tonumber(self.swapchain.extent.width) / tonumber(self.swapchain.extent.height)

	local ubo = ffi.cast(UniformBufferObject_ptr, self.uniformBuffers[self.currentFrame+1].mapped)
	self.modelMat.ptr = ubo.model
	self.modelMat:setRotate(time * math.rad(90), 0, 0, 1)
--		:transpose4x4()
	self.viewMat.ptr = ubo.view
	self.viewMat:setLookAt(
		2,2,2,
		0,0,0,
		0,0,1
	)
--		:inv4x4()
--		:transpose4x4()
	self.projMat.ptr = ubo.proj
	self.projMat:setPerspective(45, ar, .1, 10)
		:applyScale(1,-1)	-- hmm why?
		:transpose4x4()
end

function VulkanCommon:recordCommandBuffer(commandBuffer, imageIndex)
	-- TODO per vulkan api, if we just have null info, can we pass null?
	assert(commandBuffer:begin())

	commandBuffer:beginRenderPass(
		commandBuffer.makeVkRenderPassBeginInfo{
			renderPass = self.swapchain.renderPass.id,
			-- TODO how do we know the framebuffer index is less than the image from teh swapchain?
			-- framebufer[] is sized b imge of swapchain,
			-- but her it's indexed by maxFramesInFlight which is set to 2
			framebuffer = self.swapchain.framebuffers[1+imageIndex].id,
			renderArea = {
				extent = self.swapchain.extent,
			},
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
		},
		vk.VK_SUBPASS_CONTENTS_INLINE
	)

	commandBuffer:bindPipeline(
		vk.VK_PIPELINE_BIND_POINT_GRAPHICS,
		self.graphicsPipeline.obj.id
	)

	local viewports = commandBuffer.VkViewport()
	viewports.width = self.swapchain.extent.width
	viewports.height = self.swapchain.extent.height
	viewports.minDepth = 0
	viewports.maxDepth = 1
	commandBuffer:setViewport(0, 1, viewports)

	local scissors = commandBuffer.VkRect2D()
	scissors.extent.width = self.swapchain.extent.width
	scissors.extent.height = self.swapchain.extent.height
	commandBuffer:setScissors(0, 1, scissors)

	local vertexBuffers = commandBuffer.VkBuffer_array(1, self.mesh.vertexBufferAndMemory.buffer.id)
	local vertexOffsets = commandBuffer.VkDeviceSize_array(1, 0)
	commandBuffer:bindVertexBuffers(
		0,
		1,
		vertexBuffers,
		vertexOffsets
	)

	commandBuffer:bindIndexBuffer(
		self.mesh.indexBufferAndMemory.buffer.id,
		0,
		vk.VK_INDEX_TYPE_UINT32
	)

	commandBuffer:bindDescriptorSets(
		vk.VK_PIPELINE_BIND_POINT_GRAPHICS,
		self.graphicsPipeline.pipelineLayout.id,
		0,
		1,
		self.descriptorSets.idptr + self.currentFrame,
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

function VulkanCommon:recreateSwapchain()
	local app = self.app
	if app.width == 0 or app.height == 0 then
		error "here"
	end
	assert(self.device.obj:waitIdle())
	self.swapchain.obj:destroy()
	self:createSwapchain()
end

function VulkanCommon:exit()
	if self.device then
		assert(self.device.obj:waitIdle())
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

	if self.textureImageView then
		self.textureImageView:destroy()
	end
	self.textureImageView = nil

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

	if self.textureSampler then
		self.textureSampler:destroy()
	end
	self.textureSampler = nil

	if self.commandPool then
		self.commandPool:destroy()
	end
	self.commandPool = nil

	if self.graphicsPipeline then
		self.graphicsPipeline:destroy()
	end
	self.graphicsPipeline = nil

	if self.swapchain then
		self.swapchain:destroy()
	end
	self.swapchain = nil

	if self.device then
		self.device.obj:destroy()
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
		self.instance.obj:destroy()
	end
	self.instance = nil
end
--]]

return VulkanCommon
