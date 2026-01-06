--helper
local ffi = require 'ffi'
local asserteq = require 'ext.assert'.eq
local math = require 'ext.math'	-- clamp
local class = require 'ext.class'
local range = require 'ext.range'
local timer = require 'ext.timer'
local struct = require 'struct'
local vector = require 'ffi.cpp.vector-lua'
local matrix_ffi = require 'matrix.ffi'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local VKSurface = require 'vk.surface'
local VKQueue = require 'vk.queue'


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
local VKSingleTimeCommand = require 'vk.singletimecommand'


vk.VK_KHR_SWAPCHAIN_EXTENSION_NAME = "VK_KHR_swapchain"


local float = ffi.typeof'float'
local void_ptr = ffi.typeof'void*'
local char_const_ptr = ffi.typeof'char const *'
local uint32_t_1 = ffi.typeof'uint32_t[1]'
local uint64_t = ffi.typeof'uint64_t'
local VkDescriptorPoolSize = ffi.typeof'VkDescriptorPoolSize'
local VkDescriptorPool = ffi.typeof'VkDescriptorPool'
local VkCommandBuffer = ffi.typeof'VkCommandBuffer'
local VkSemaphore = ffi.typeof'VkSemaphore'
local VkFence = ffi.typeof'VkFence'
local VkDescriptorSet = ffi.typeof'VkDescriptorSet'
local VkWriteDescriptorSet = ffi.typeof'VkWriteDescriptorSet'
local VkClearValue = ffi.typeof'VkClearValue'
local VkDescriptorSetLayout = ffi.typeof'VkDescriptorSetLayout'
local VkSampler = ffi.typeof'VkSampler'
local VkSamplerCreateInfo_1 = ffi.typeof'VkSamplerCreateInfo[1]'
local VkDescriptorPoolCreateInfo_1 = ffi.typeof'VkDescriptorPoolCreateInfo[1]'
local VkCommandBufferAllocateInfo_1 = ffi.typeof'VkCommandBufferAllocateInfo[1]'
local VkSemaphoreCreateInfo_1 = ffi.typeof'VkSemaphoreCreateInfo[1]'
local VkFenceCreateInfo_1 = ffi.typeof'VkFenceCreateInfo[1]'
local VkImageMemoryBarrier_1 = ffi.typeof'VkImageMemoryBarrier[1]'
local VkImageBlit_1 = ffi.typeof'VkImageBlit[1]'
local VkDescriptorSetAllocateInfo_1 = ffi.typeof'VkDescriptorSetAllocateInfo[1]'
local VkDescriptorBufferInfo_1 = ffi.typeof'VkDescriptorBufferInfo[1]'
local VkDescriptorImageInfo_1 = ffi.typeof'VkDescriptorImageInfo[1]'
local VkAcquireNextImageInfoKHR_1 = ffi.typeof'VkAcquireNextImageInfoKHR[1]'
local VkPipelineStageFlags_1 = ffi.typeof'VkPipelineStageFlags[1]'
local VkSubmitInfo_1 = ffi.typeof'VkSubmitInfo[1]'
local VkSwapchainKHR_1 = ffi.typeof'VkSwapchainKHR[1]'
local VkPresentInfoKHR_1 = ffi.typeof'VkPresentInfoKHR[1]'
local VkCommandBufferBeginInfo_1 = ffi.typeof'VkCommandBufferBeginInfo[1]'
local VkRenderPassBeginInfo_1 = ffi.typeof'VkRenderPassBeginInfo[1]'
local VkViewport_1 = ffi.typeof'VkViewport[1]'
local VkRect2D_1 = ffi.typeof'VkRect2D[1]'
local VkBuffer_1 = ffi.typeof'VkBuffer[1]'
local VkDeviceSize_1 = ffi.typeof'VkDeviceSize[1]'


local UniformBufferObject = struct{
	name = 'UniformBufferObject',
	fields = {
		{name = 'model', type = 'float[16]'},
		{name = 'view', type = 'float[16]'},
		{name = 'proj', type = 'float[16]'},
	},
}
asserteq(ffi.sizeof(UniformBufferObject), 4 * 4 * ffi.sizeof(float) * 3)


local VulkanCommon = class()

VulkanCommon.enableValidationLayers = false
VulkanCommon.maxFramesInFlight = 2

function VulkanCommon:init(app)
	self.app = assert(app)
	self.framebufferResized = false
	self.currentFrame = 0

	assert(not self.enableValidationLayers or self:checkValidationLayerSupport(), "validation layers requested, but not available!")
	self.instance = VulkanInstance(self)

	self.surface = VKSurface{
		window = app.window,
		instance = self.instance.obj,
	}

	self.deviceExtensions = vector(char_const_ptr)
	self.deviceExtensions:emplace_back()[0] = vk.VK_KHR_SWAPCHAIN_EXTENSION_NAME

	self.physDev = VulkanPhysicalDevice(self, self.deviceExtensions)

	self.msaaSamples = self.physDev:getMaxUsableSampleCount()
print('msaaSamples', self.msaaSamples)

	do
		local indices = self.physDev:findQueueFamilies(nil, self.surface)
		self.device = VulkanDevice(
			self.physDev.obj,
			self.deviceExtensions,
			self.enableValidationLayers,
			indices
		)
		self.graphicsQueue = VKQueue{device=self.device.obj, family=indices.graphicsFamily}
		self.presentQueue = VKQueue{device=self.device.obj, family=indices.presentFamily}
	end
	self.deviceExtensions = nil

	self:createSwapchain()

	self.graphicsPipeline = VulkanGraphicsPipeline(self.physDev, self.device.obj.id, self.swapchain.renderPass, self.msaaSamples)

	self.commandPool = VulkanCommandPool(self, self.physDev, self.device, self.surface)

	self.textureImageAndMemory = self:createTextureImage()

	self.textureImageView = self.swapchain:createImageView(
		self.device.obj.id,
		self.textureImageAndMemory.image,
		vk.VK_FORMAT_R8G8B8A8_SRGB,
		vk.VK_IMAGE_ASPECT_COLOR_BIT,
		self.mipLevels)

	self.info = ffi.new(VkSamplerCreateInfo_1, {{
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
	}})
	self.textureSampler = vkGet(VkSampler, vkassert, vk.vkCreateSampler, self.device.obj.id, self.info, nil)
	self.info = nil

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
		local mapped = vkGet(void_ptr, vkassert, vk.vkMapMemory, self.device.obj.id, bm.memory, 0, size, 0)
		return VulkanBufferMemoryAndMapped(bm, mapped)
	end)

	self.poolSizes = vector(VkDescriptorPoolSize, {
		{
			type = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
			descriptorCount = self.maxFramesInFlight,
		},
		{
			type = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
			descriptorCount = self.maxFramesInFlight,
		}
	})
	self.info = ffi.new(VkDescriptorPoolCreateInfo_1, {{
		sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
		maxSets = self.maxFramesInFlight,
		poolSizeCount = #self.poolSizes,
		pPoolSizes = self.poolSizes.v,
	}})
	self.descriptorPool = vkGet(VkDescriptorPool, vkassert, vk.vkCreateDescriptorPool, self.device.obj.id, self.info, nil)
	self.info = nil
	self.poolSizes = nil

	self.descriptorSets = self:createDescriptorSets()

	self.info = ffi.new(VkCommandBufferAllocateInfo_1, {{
		sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
		commandPool = self.commandPool.id,
		level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
		commandBufferCount = self.maxFramesInFlight,
	}})
	--[[
	self.commandBuffers = vkGet(VkCommandBuffer, vkassert, vk.vkAllocateCommandBuffers, self.device.obj.id, self.info)
	--]]
	-- [[ can't use vkGet and can't use vkGetVector ...
	self.commandBuffers = vector(VkCommandBuffer)
	self.commandBuffers:resize(self.maxFramesInFlight)
	vkassert(vk.vkAllocateCommandBuffers, self.device.obj.id, self.info, self.commandBuffers.v)
	--]]
	self.info = nil

	self.imageAvailableSemaphores = vector(VkSemaphore)
	for i=0,self.maxFramesInFlight-1 do
		self.info = ffi.new(VkSemaphoreCreateInfo_1, {{
			sType = vk.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
		}})
		self.imageAvailableSemaphores:push_back(vkGet(VkSemaphore, vkassert, vk.vkCreateSemaphore, self.device.obj.id, self.info, nil))
		self.info = nil
	end

	self.renderFinishedSemaphores = vector(VkSemaphore)
	for i=0,self.maxFramesInFlight-1 do
		self.info = ffi.new(VkSemaphoreCreateInfo_1, {{
			sType = vk.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
		}})
		self.renderFinishedSemaphores:push_back(vkGet(VkSemaphore, vkassert, vk.vkCreateSemaphore, self.device.obj.id, self.info, nil))
		self.info = nil
	end

	self.inFlightFences = vector(VkFence)
	for i=0,self.maxFramesInFlight-1 do
		self.info = ffi.new(VkFenceCreateInfo_1, {{
			sType = vk.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
			flags = vk.VK_FENCE_CREATE_SIGNALED_BIT,
		}})
		self.inFlightFences:push_back(vkGet(VkFence, vkassert, vk.vkCreateFence, self.device.obj.id, self.info, nil))
		self.info = nil
	end
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
		textureImageAndMemory.image,
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

	VKSingleTimeCommand(
		self.device.obj.id,
		self.graphicsQueue.id,
		self.commandPool.id,
		function(commandBuffer)
			self.barrier = ffi.new(VkImageMemoryBarrier_1, {{
				srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED,
				dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED,
				image = image,
				subresourceRange = {
					aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
					levelCount = 1,
					layerCount = 1,
				},
			}})

			local mipWidth = texWidth
			local mipHeight = texHeight

			for i=1,mipLevels-1 do
				self.barrier[0].subresourceRange.baseMipLevel = i - 1
				self.barrier[0].oldLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
				self.barrier[0].newLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL
				self.barrier[0].srcAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT
				self.barrier[0].dstAccessMask = vk.VK_ACCESS_TRANSFER_READ_BIT

				vk.vkCmdPipelineBarrier(
					commandBuffer,						-- commandBuffer
					vk.VK_PIPELINE_STAGE_TRANSFER_BIT,  -- srcStageMask
					vk.VK_PIPELINE_STAGE_TRANSFER_BIT,	-- dstStageMask
					0,									-- dependencyFlags
					0,									-- memoryBarrierCount
					nil,								-- pMemoryBarriers
					0,									-- bufferMemoryBarrierCount
					nil,								-- pBufferMemoryBarriers
					1,									-- imageMemoryBarrierCount
					self.barrier						-- pImageMemoryBarriers
				)

				self.blit = ffi.new(VkImageBlit_1)
				self.blit[0].srcSubresource.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT
				self.blit[0].srcSubresource.mipLevel = i-1
				self.blit[0].srcSubresource.layerCount = 1
				self.blit[0].srcOffsets[1].x = mipWidth
				self.blit[0].srcOffsets[1].y = mipHeight
				self.blit[0].srcOffsets[1].z = 1
				self.blit[0].dstSubresource.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT
				self.blit[0].dstSubresource.mipLevel = i
				self.blit[0].dstSubresource.layerCount = 1
				self.blit[0].dstOffsets[1].x = mipWidth > 1 and math.floor(mipWidth / 2) or 1
				self.blit[0].dstOffsets[1].y = mipHeight > 1 and math.floor(mipHeight / 2) or 1
				self.blit[0].dstOffsets[1].z = 1

				vk.vkCmdBlitImage(
					commandBuffer,
					image,
					vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
					image,
					vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
					1,
					self.blit,
					vk.VK_FILTER_LINEAR
				)
				self.blit = nil

				self.barrier[0].oldLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL
				self.barrier[0].newLayout = vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
				self.barrier[0].srcAccessMask = vk.VK_ACCESS_TRANSFER_READ_BIT
				self.barrier[0].dstAccessMask = vk.VK_ACCESS_SHADER_READ_BIT

				vk.vkCmdPipelineBarrier(
					commandBuffer,								-- commandBuffer
					vk.VK_PIPELINE_STAGE_TRANSFER_BIT,  		-- srcStageMask
					vk.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,   -- dstStageMask
					0,											-- dependencyFlags
					0,											-- memoryBarrierCount
					nil,										-- pMemoryBarriers
					0,											-- bufferMemoryBarrierCount
					nil,										-- pBufferMemoryBarriers
					1,											-- imageMemoryBarrierCount
					self.barrier								-- pImageMemoryBarriers
				)

				if mipWidth > 1 then mipWidth = math.floor(mipWidth / 2) end
				if mipHeight > 1 then mipHeight = math.floor(mipHeight / 2) end
			end

			self.barrier[0].subresourceRange.baseMipLevel = mipLevels - 1;
			self.barrier[0].oldLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
			self.barrier[0].newLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL
			self.barrier[0].srcAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT
			self.barrier[0].dstAccessMask = vk.VK_ACCESS_TRANSFER_READ_BIT

			vk.vkCmdPipelineBarrier(
				commandBuffer,								-- commandBuffer
				vk.VK_PIPELINE_STAGE_TRANSFER_BIT,  		-- srcStageMask
				vk.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,   -- dstStageMask
				0,											-- dependencyFlags
				0,											-- memoryBarrierCount
				nil,										-- pMemoryBarriers
				0,											-- bufferMemoryBarrierCount
				nil,										-- pBufferMemoryBarriers
				1,											-- imageMemoryBarrierCount
				self.barrier								-- pImageMemoryBarriers
			)

			self.barrier = nil
		end
	)
end

function VulkanCommon:createDescriptorSets()
	self.layouts = vector(VkDescriptorSetLayout)
	for i=0,self.maxFramesInFlight-1 do
		self.layouts:push_back(self.graphicsPipeline.descriptorSetLayout)
	end

	self.info = ffi.new(VkDescriptorSetAllocateInfo_1, {{
		sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
		descriptorPool = self.descriptorPool,
		descriptorSetCount = #self.layouts, -- self.maxFramesInFlight
		pSetLayouts = self.layouts.v,	-- length matches descriptorSetCount I think?
	}})

	--[[ vkGet just allocates one
	-- vkGetVector expects a 'count' field to determine size
	-- ... we have to statically allocate for this function ...
	local descriptorSets = vkGet(VkDescriptorSet,
		vkassert,
		vk.vkAllocateDescriptorSets,
		self.device.obj.id,
		self.info
	)
	--]]
	-- [[
	local descriptorSets = vector(VkDescriptorSet)
	descriptorSets:resize(self.maxFramesInFlight)
	vkassert(vk.vkAllocateDescriptorSets, self.device.obj.id, self.info, descriptorSets.v)
	--]]
	self.info = nil
	self.layouts = nil

	for i=0,self.maxFramesInFlight-1 do
		self.bufferInfo = ffi.new(VkDescriptorBufferInfo_1, {{
			buffer = self.uniformBuffers[i+1].buffer,
			range = ffi.sizeof(UniformBufferObject),
		}})

		self.imageInfo = ffi.new(VkDescriptorImageInfo_1, {{
			sampler = self.textureSampler,
			imageView = self.textureImageView,
			imageLayout = vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
		}})

		self.descriptorWrites = vector(VkWriteDescriptorSet, {
			{
				sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
				dstSet = descriptorSets.v[i],
				dstBinding = 0,
				descriptorCount = 1,
				descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
				pBufferInfo = self.bufferInfo,
			},
			{
				sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
				dstSet = descriptorSets.v[i],
				dstBinding = 1,
				descriptorCount = 1,
				descriptorType = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
				pImageInfo = self.imageInfo,
			},
		})

		vk.vkUpdateDescriptorSets(
			self.device.obj.id,
			#self.descriptorWrites,
			self.descriptorWrites.v,
			0,
			nil)

		self.descriptorWrites = nil
		self.imageInfo = nil
		self.bufferInfo = nil
	end

	return descriptorSets
end

function VulkanCommon:setFramebufferResized()
	self.framebufferResized = true
end

function VulkanCommon:drawFrame()
-- right here once all the first set of frames are exhausted, this stalls indefinitely
	local result = vk.vkWaitForFences(
		self.device.obj.id,
		1,
		self.inFlightFences.v + self.currentFrame,
		vk.VK_TRUE,
		ffi.cast(uint64_t, -1)	-- UINT64_MAX
	)
	if result ~= vk.VK_SUCCESS then
		error("vkWaitForRences failed: "..tostring(result))
	end

	local imageIndex = ffi.new(uint32_t_1)
	self.info = ffi.new(VkAcquireNextImageInfoKHR_1, {{
		sType = vk.VK_STRUCTURE_TYPE_ACQUIRE_NEXT_IMAGE_INFO_KHR,
		pNext = nil,
		swapchain = self.swapchain.obj.id,
		timeout = ffi.cast(uint64_t, -1),
		semaphore = self.imageAvailableSemaphores.v[self.currentFrame],
		fence = nil,
		deviceMask = 0,
	}})
	local result = vk.vkAcquireNextImage2KHR(assert(self.device.obj.id), self.info, imageIndex)
	self.info = nil
	if result == vk.VK_ERROR_OUT_OF_DATE_KHR then
		self:recreateSwapchain()
		return
	elseif result ~= vk.VK_SUCCESS
	and result ~= vk.VK_SUBOPTIMAL_KHR
	then
		error("vkAcquireNextImage2KHR failed: "..tostring(result))
	end

	self:updateUniformBuffer()

	vkassert(vk.vkResetFences, self.device.obj.id, 1, self.inFlightFences.v + self.currentFrame)

	vkassert(vk.vkResetCommandBuffer, self.commandBuffers.v[self.currentFrame], 0)

	self:recordCommandBuffer(self.commandBuffers.v[self.currentFrame], imageIndex[0])

	self.waitStages = ffi.new(VkPipelineStageFlags_1, vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT)
	self.info = ffi.new(VkSubmitInfo_1, {{
		sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO,
		waitSemaphoreCount = 1,
		pWaitSemaphores = self.imageAvailableSemaphores.v + self.currentFrame,
		pWaitDstStageMask = self.waitStages,
		commandBufferCount = 1,
		pCommandBuffers = self.commandBuffers.v + self.currentFrame,
		signalSemaphoreCount = 1,
		pSignalSemaphores = self.renderFinishedSemaphores.v + self.currentFrame,
	}})
	vkassert(vk.vkQueueSubmit, self.graphicsQueue.id, 1, self.info, self.inFlightFences.v[self.currentFrame])
	self.waitStages = nil

	-- TODO reason to keep the gc'd ptr around
	self.swapchains = ffi.new(VkSwapchainKHR_1, self.swapchain.obj.id)
	self.info = ffi.new(VkPresentInfoKHR_1, {{
		sType = vk.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
		waitSemaphoreCount = 1,
		pWaitSemaphores = self.renderFinishedSemaphores.v + self.currentFrame,
		swapchainCount = 1,
		pSwapchains = self.swapchains,
		pImageIndices = imageIndex,
	}})
	-- TODO what's self.info.pResults vs the results returned from vkQueuePresentKHR ?
	local result = vk.vkQueuePresentKHR(self.presentQueue.id, self.info)
	self.info = nil
	self.swapchains = nil

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

local identMat = matrix_ffi({
	{1,0,0,0},
	{0,1,0,0},
	{0,0,1,0},
	{0,0,0,1},
}, float)

VulkanCommon.startTime = timer.getTime()
function VulkanCommon:updateUniformBuffer()
	local app = self.app
	local currentTime = timer.getTime()
	local time = currentTime - self.startTime

-- don't need this unless I start doing the matrix calculations here
--	local ar = tonumber(self.swapchain.extent.width) / tonumber(self.swapchain.extent.height)

	local ubo = UniformBufferObject()
-- [[ TODO maybe transpose ...
	ffi.copy(ubo.model, app.view.mvMat.ptr, 4 * 4 * ffi.sizeof(float))
	ffi.copy(ubo.view, identMat.ptr, 4 * 4 * ffi.sizeof(float))
	ffi.copy(ubo.proj, app.view.projMat.ptr, 4 * 4 * ffi.sizeof(float))
--]]
--[[ transposed?
	for i=0,3 do
		for j=0,3 do
			ubo.model[i+4*j] = app.view.mvMat.ptr[j+4*i]
			ubo.view[i+4*j] = identMat.ptr[j+4*i]
			ubo.proj[i+4*j] = app.view.projMat.ptr[j+4*i]
		end
	end
--]]
	ffi.copy(self.uniformBuffers[self.currentFrame+1].mapped, ubo, ffi.sizeof(UniformBufferObject))
end

function VulkanCommon:recordCommandBuffer(commandBuffer, imageIndex)
	-- TODO per vulkan api, if we just have null info, can we pass null?
	self.info = ffi.new(VkCommandBufferBeginInfo_1, {{
		sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
	}})
	vkassert(vk.vkBeginCommandBuffer, commandBuffer, self.info)
	self.info = nil

	self.clearValues = vector(VkClearValue)
	local c = self.clearValues:emplace_back()
	c[0].color.float32[0] = 0
	c[0].color.float32[1] = 0
	c[0].color.float32[2] = 0
	c[0].color.float32[3] = 1
	local c = self.clearValues:emplace_back()
	c[0].depthStencil.depth = 1
	c[0].depthStencil.stencil = 0

	self.info = ffi.new(VkRenderPassBeginInfo_1, {{
		sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
		renderPass = self.swapchain.renderPass,
		framebuffer = self.swapchain.framebuffers.v[imageIndex],
		-- TODO will equals assign here, or will it just mess things up?
		renderArea = {
			extent = {
				width = self.swapchain.extent.width,
				height = self.swapchain.extent.height,
			},
		},
		clearValueCount = #self.clearValues,
		pClearValues = self.clearValues.v,
	}})
	vk.vkCmdBeginRenderPass(commandBuffer, self.info, vk.VK_SUBPASS_CONTENTS_INLINE)
	self.info = nil
	self.clearValues = nil

	vk.vkCmdBindPipeline(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, self.graphicsPipeline.id)

	self.viewports = ffi.new(VkViewport_1, {{
		width = self.swapchain.extent.width,
		height = self.swapchain.extent.height,
		minDepth = 0,
		maxDepth = 1,
	}})
	vk.vkCmdSetViewport(commandBuffer, 0, 1, self.viewports)
	self.viewports = nil

	self.scissors = ffi.new(VkRect2D_1, {{
		extent = {
			width = self.swapchain.extent.width,
			height = self.swapchain.extent.height,
		},
	}})
	vk.vkCmdSetScissor(commandBuffer, 0, 1, self.scissors)
	self.scissors = nil

	self.vertexBuffers = ffi.new(VkBuffer_1, (assert(self.mesh.vertexBufferAndMemory.buffer.id)))
	self.vertexOffsets = ffi.new(VkDeviceSize_1)
	vk.vkCmdBindVertexBuffers(commandBuffer, 0, 1, self.vertexBuffers, self.vertexOffsets)
	self.vertexOffsets = nil
	self.vertexBuffers = nil

	vk.vkCmdBindIndexBuffer(
		commandBuffer,
		assert(self.mesh.indexBufferAndMemory.buffer.id),
		0,
		vk.VK_INDEX_TYPE_UINT32
	)

	vk.vkCmdBindDescriptorSets(
		commandBuffer,
		vk.VK_PIPELINE_BIND_POINT_GRAPHICS,
		self.graphicsPipeline.pipelineLayout,
		0,
		1,
		self.descriptorSets.v + self.currentFrame,
		0,
		nil
	)

	vk.vkCmdDrawIndexed(
		commandBuffer,
		assert(self.mesh.numIndices),
		1,
		0,
		0,
		0
	)

	vk.vkCmdEndRenderPass(commandBuffer)
	vk.vkEndCommandBuffer(commandBuffer)
end

function VulkanCommon:recreateSwapchain()
	local app = self.app
	if app.width == 0 or app.height == 0 then
		error "here"
	end

	self.device.obj:waitIdle()

	self:createSwapchain()
end

function VulkanCommon:exit()
	self.device.obj:waitIdle()

	-- hmm raii isnt so fun when order matters but the scripting language gc doesn't care ...
	-- gc'd pointers would fix this ...
	for _,ub in ipairs(self.uniformBuffers) do
		ub.bm.buffer:destroy()
	end
	self.mesh.vertexBufferAndMemory.buffer:destroy()
	self.mesh.indexBufferAndMemory.buffer:destroy()

	self.swapchain.obj:destroy()
	self.device.obj:destroy()
	self.surface:destroy()
	self.instance.obj:destroy()
end
--]]

return VulkanCommon 
