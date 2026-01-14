--helper
local ffi = require 'ffi'
local asserteq = require 'ext.assert'.eq
local assertindex = require 'ext.assert'.index
local math = require 'ext.math'	-- clamp
local class = require 'ext.class'
local range = require 'ext.range'
local timer = require 'ext.timer'
local struct = require 'struct'
local vector = require 'ffi.cpp.vector-lua'
local matrix_ffi = require 'matrix.ffi'
local vk = require 'vk'
local defs = require 'vk.defs'
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
local VkSemaphoreCreateInfo = ffi.typeof'VkSemaphoreCreateInfo'
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
	self.deviceExtensions:emplace_back()[0] = assertindex(defs, 'VK_KHR_SWAPCHAIN_EXTENSION_NAME')

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

	self.info = VkSamplerCreateInfo_1()
	self.info[0].magFilter = vk.VK_FILTER_LINEAR
	self.info[0].minFilter = vk.VK_FILTER_LINEAR
	self.info[0].mipmapMode = vk.VK_SAMPLER_MIPMAP_MODE_LINEAR
	self.info[0].addressModeU = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT
	self.info[0].addressModeV = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT
	self.info[0].addressModeW = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT
	self.info[0].anisotropyEnable = vk.VK_TRUE
	self.info[0].maxAnisotropy = self.physDev.obj:getProps().limits.maxSamplerAnisotropy
	self.info[0].compareEnable = vk.VK_FALSE
	self.info[0].compareOp = vk.VK_COMPARE_OP_ALWAYS
	self.info[0].minLod = 0
	self.info[0].maxLod = self.mipLevels
	self.info[0].borderColor = vk.VK_BORDER_COLOR_INT_OPAQUE_BLACK
	self.info[0].unnormalizedCoordinates = vk.VK_FALSE

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

	local poolSizeCount = 2
	self.poolSizes = ffi.new(ffi.typeof('$[?]', VkDescriptorPoolSize), poolSizeCount)
	self.poolSizes[0].type = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
	self.poolSizes[0].descriptorCount = self.maxFramesInFlight
	self.poolSizes[1].type = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
	self.poolSizes[1].descriptorCount = self.maxFramesInFlight
	self.info = VkDescriptorPoolCreateInfo_1()
	self.info[0].sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO
	self.info[0].maxSets = self.maxFramesInFlight
	self.info[0].poolSizeCount = poolSizeCount
	self.info[0].pPoolSizes = self.poolSizes
	self.descriptorPool = vkGet(
		VkDescriptorPool,
		vkassert,
		vk.vkCreateDescriptorPool,
		self.device.obj.id,
		self.info,
		nil
	)
	self.info = nil
	self.poolSizes = nil

	self.descriptorSets = self:createDescriptorSets()

	self.info = VkCommandBufferAllocateInfo_1()
	self.info[0].sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
	self.info[0].commandPool = self.commandPool.id
	self.info[0].level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY
	self.info[0].commandBufferCount = self.maxFramesInFlight
	--[[
	self.commandBuffers = vkGet(VkCommandBuffer, vkassert, vk.vkAllocateCommandBuffers, self.device.obj.id, self.info)
	--]]
	-- [[ can't use vkGet and can't use vkGetVector ...
	self.commandBuffers = ffi.new(ffi.typeof('$[?]', VkCommandBuffer), self.maxFramesInFlight)
	vkassert(vk.vkAllocateCommandBuffers, self.device.obj.id, self.info, self.commandBuffers)
	--]]
	self.info = nil

	self.imageAvailableSemaphores = ffi.new(ffi.typeof('$[?]', VkSemaphore), self.maxFramesInFlight)
	for i=0,self.maxFramesInFlight-1 do
		self.info = VkSemaphoreCreateInfo()
		self.info.sType = vk.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
		self.imageAvailableSemaphores[i] = vkGet(
			VkSemaphore,
			vkassert,
			vk.vkCreateSemaphore,
			self.device.obj.id,
			self.info,
			nil
		)
		self.info = nil
	end

	self.renderFinishedSemaphores = ffi.new(ffi.typeof('$[?]', VkSemaphore), self.maxFramesInFlight)
	for i=0,self.maxFramesInFlight-1 do
		self.info = VkSemaphoreCreateInfo()
		self.info.sType = vk.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
		self.renderFinishedSemaphores[i] = vkGet(
			VkSemaphore,
			vkassert,
			vk.vkCreateSemaphore,
			self.device.obj.id,
			self.info,
			nil
		)
		self.info = nil
	end

	self.inFlightFences = ffi.new(ffi.typeof('$[?]', VkFence), self.maxFramesInFlight)
	for i=0,self.maxFramesInFlight-1 do
		self.info = VkFenceCreateInfo_1()
		self.info[0].sType = vk.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO
		self.info[0].flags = vk.VK_FENCE_CREATE_SIGNALED_BIT
		self.inFlightFences[i] = vkGet(
			VkFence,
			vkassert,
			vk.vkCreateFence,
			self.device.obj.id,
			self.info,
			nil
		)
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
			self.barrier = VkImageMemoryBarrier_1()
			self.barrier[0].srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED
			self.barrier[0].dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED
			self.barrier[0].image = image
			self.barrier[0].subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT
			self.barrier[0].subresourceRange.levelCount = 1
			self.barrier[0].subresourceRange.layerCount = 1

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

				self.blit = VkImageBlit_1()
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
	self.layouts = ffi.new(ffi.typeof('$[?]', VkDescriptorSetLayout), self.maxFramesInFlight)
	for i=0,self.maxFramesInFlight-1 do
		self.layouts[i] = self.graphicsPipeline.descriptorSetLayout
	end

	self.info = VkDescriptorSetAllocateInfo_1()
	self.info[0].sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO
	self.info[0].descriptorPool = self.descriptorPool
	self.info[0].descriptorSetCount = self.maxFramesInFlight
	self.info[0].pSetLayouts = self.layouts	-- length matches descriptorSetCount I think?

	--[[ vkGet just allocates one
	-- vkGetVector expects a 'count' field to determine size
	-- ... we have to statically allocate for this function ...
	descriptorSets = vkGet(
		VkDescriptorSet,
		vkassert,
		vk.vkAllocateDescriptorSets,
		self.device.obj.id,
		self.info
	)
	--]]
	-- [[
	local descriptorSets = ffi.new(ffi.typeof('$[?]', VkDescriptorSet), self.maxFramesInFlight)
	vkassert(vk.vkAllocateDescriptorSets, self.device.obj.id, self.info, descriptorSets)
	--]]
	self.info = nil
	self.layouts = nil

	for i=0,self.maxFramesInFlight-1 do
		self.bufferInfo = VkDescriptorBufferInfo_1()
		self.bufferInfo[0].buffer = self.uniformBuffers[i+1].buffer
		self.bufferInfo[0].range = ffi.sizeof(UniformBufferObject)

		self.imageInfo = VkDescriptorImageInfo_1()
		self.imageInfo[0].sampler = self.textureSampler
		self.imageInfo[0].imageView = self.textureImageView
		self.imageInfo[0].imageLayout = vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL

		local numDescriptorWrites = 2
		self.descriptorWrites = ffi.new(ffi.typeof('$[?]', VkWriteDescriptorSet), numDescriptorWrites)
		local v = self.descriptorWrites+0
		v.sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
		v.dstSet = descriptorSets[i]
		v.dstBinding = 0
		v.descriptorCount = 1
		v.descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
		v.pBufferInfo = self.bufferInfo
		v=v+1
		v.sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
		v.dstSet = descriptorSets[i]
		v.dstBinding = 1
		v.descriptorCount = 1
		v.descriptorType = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
		v.pImageInfo = self.imageInfo
		v=v+1
		asserteq(v, self.descriptorWrites + numDescriptorWrites)

		vk.vkUpdateDescriptorSets(
			self.device.obj.id,
			numDescriptorWrites,
			self.descriptorWrites,
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
		self.inFlightFences + self.currentFrame,
		vk.VK_TRUE,
		ffi.cast(uint64_t, -1)	-- UINT64_MAX
	)
	if result ~= vk.VK_SUCCESS then
		error("vkWaitForRences failed: "..tostring(result))
	end

	self.imageIndex = uint32_t_1()
	self.info = VkAcquireNextImageInfoKHR_1()
	self.info[0].sType = vk.VK_STRUCTURE_TYPE_ACQUIRE_NEXT_IMAGE_INFO_KHR
	self.info[0].pNext = nil
	self.info[0].swapchain = self.swapchain.obj.id
	self.info[0].timeout = ffi.cast(uint64_t, -1)
	self.info[0].semaphore = self.imageAvailableSemaphores[self.currentFrame]
	self.info[0].fence = nil
	self.info[0].deviceMask = 1
	local result = vk.vkAcquireNextImage2KHR(assert(self.device.obj.id), self.info, self.imageIndex)
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

	vkassert(vk.vkResetFences, self.device.obj.id, 1, self.inFlightFences + self.currentFrame)

	vkassert(vk.vkResetCommandBuffer, self.commandBuffers[self.currentFrame], 0)

	self:recordCommandBuffer(self.commandBuffers[self.currentFrame], self.imageIndex[0])

	self.waitStages = VkPipelineStageFlags_1(vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT)

	self.info = VkSubmitInfo_1()
	self.info[0].sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO
	self.info[0].waitSemaphoreCount = 1
	self.info[0].pWaitSemaphores = self.imageAvailableSemaphores + self.currentFrame
	self.info[0].pWaitDstStageMask = self.waitStages
	self.info[0].commandBufferCount = 1
	self.info[0].pCommandBuffers = self.commandBuffers + self.currentFrame
	self.info[0].signalSemaphoreCount = 1
	self.info[0].pSignalSemaphores = self.renderFinishedSemaphores + self.currentFrame
	vkassert(vk.vkQueueSubmit, self.graphicsQueue.id, 1, self.info, self.inFlightFences[self.currentFrame])
	self.waitStages = nil

	-- TODO reason to keep the gc'd ptr around
	self.swapchains = VkSwapchainKHR_1()
	self.swapchains[0] = self.swapchain.obj.id
	self.info = VkPresentInfoKHR_1()
	self.info[0].sType = vk.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR
	self.info[0].waitSemaphoreCount = 1
	self.info[0].pWaitSemaphores = self.renderFinishedSemaphores + self.currentFrame
	self.info[0].swapchainCount = 1
	self.info[0].pSwapchains = self.swapchains
	self.info[0].pImageIndices = self.imageIndex
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
	self.info = VkCommandBufferBeginInfo_1()
	self.info[0].sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
	vkassert(vk.vkBeginCommandBuffer, commandBuffer, self.info)
	self.info = nil

	local numClearValues = 2
	self.clearValues = ffi.new(ffi.typeof('$[?]', VkClearValue), numClearValues)
	local c = self.clearValues+0
	c.color.float32[0] = 0
	c.color.float32[1] = 0
	c.color.float32[2] = 0
	c.color.float32[3] = 1
	local c = self.clearValues+1
	c.depthStencil.depth = 1
	c.depthStencil.stencil = 0

	self.info = VkRenderPassBeginInfo_1()
	self.info[0].sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO
	self.info[0].renderPass = self.swapchain.renderPass
	self.info[0].framebuffer = self.swapchain.framebuffers.v[imageIndex]
	self.info[0].renderArea.extent.width = self.swapchain.extent.width
	self.info[0].renderArea.extent.height = self.swapchain.extent.height
	self.info[0].clearValueCount = numClearValues
	self.info[0].pClearValues = self.clearValues
	vk.vkCmdBeginRenderPass(
		commandBuffer,
		self.info,
		vk.VK_SUBPASS_CONTENTS_INLINE
	)
	self.info = nil
	self.clearValues = nil

	vk.vkCmdBindPipeline(
		commandBuffer,
		vk.VK_PIPELINE_BIND_POINT_GRAPHICS,
		self.graphicsPipeline.id
	)

	self.viewports = VkViewport_1()
	self.viewports[0].width = self.swapchain.extent.width
	self.viewports[0].height = self.swapchain.extent.height
	self.viewports[0].minDepth = 0
	self.viewports[0].maxDepth = 1
	vk.vkCmdSetViewport(commandBuffer, 0, 1, self.viewports)
	self.viewports = nil

	self.scissors = VkRect2D_1()
	self.scissors[0].extent.width = self.swapchain.extent.width
	self.scissors[0].extent.height = self.swapchain.extent.height
	vk.vkCmdSetScissor(commandBuffer, 0, 1, self.scissors)
	self.scissors = nil

	self.vertexBuffers = VkBuffer_1()
	self.vertexBuffers[0] = assert(self.mesh.vertexBufferAndMemory.buffer.id)
	self.vertexOffsets = VkDeviceSize_1()
	self.vertexOffsets[0] = 0
	vk.vkCmdBindVertexBuffers(
		commandBuffer,
		0,
		1,
		self.vertexBuffers,
		self.vertexOffsets
	)
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
		self.descriptorSets + self.currentFrame,
		0,
		nil
	)

	vk.vkCmdDrawIndexed(
		commandBuffer,
		self.mesh.numIndices,
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

	self.swapchain.obj:destroy()
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
