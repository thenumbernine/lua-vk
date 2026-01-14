-- helper
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local VKSingleTimeCommand = require 'vk.singletimecommand'


local VkCommandPool = ffi.typeof'VkCommandPool'
local VkCommandPoolCreateInfo = ffi.typeof'VkCommandPoolCreateInfo'
local VkImageMemoryBarrier = ffi.typeof'VkImageMemoryBarrier'
local VkBufferCopy = ffi.typeof'VkBufferCopy'
local VkBufferImageCopy = ffi.typeof'VkBufferImageCopy'


local VulkanCommandPool = class()

function VulkanCommandPool:init(common, physDev, device, surface)
	local queueFamilyIndices = physDev:findQueueFamilies(nil, surface)

	self.info = VkCommandPoolCreateInfo()
	self.info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
	self.info.flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT
	self.info.queueFamilyIndex = assert.index(queueFamilyIndices, 'graphicsFamily')
	self.id = vkGet(VkCommandPool, vkassert, vk.vkCreateCommandPool, device.obj.id, self.info, nil)
	self.info = nil

	self.device = device.obj.id
	self.graphicsQueue = common.graphicsQueue
end

function VulkanCommandPool:transitionImageLayout(image, oldLayout, newLayout, mipLevels)
	VKSingleTimeCommand(
		self.device,
		self.graphicsQueue.id,
		self.id,
		function(commandBuffer)
			self.barrier = VkImageMemoryBarrier()
			self.barrier.sType = vk.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER
			self.barrier.oldLayout = oldLayout
			self.barrier.newLayout = newLayout
			self.barrier.srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED
			self.barrier.dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED
			self.barrier.image = image
			self.barrier.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT
			self.barrier.subresourceRange.levelCount = mipLevels
			self.barrier.subresourceRange.layerCount = 1

			local srcStage, dstStage
			if oldLayout == vk.VK_IMAGE_LAYOUT_UNDEFINED
			and newLayout == vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
			then
				self.barrier.srcAccessMask = 0
				self.barrier.dstAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT
				srcStage = vk.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT
				dstStage = vk.VK_PIPELINE_STAGE_TRANSFER_BIT
			elseif oldLayout == vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
			and newLayout == vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
			then
				self.barrier.srcAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT
				self.barrier.dstAccessMask = vk.VK_ACCESS_SHADER_READ_BIT
				srcStage = vk.VK_PIPELINE_STAGE_TRANSFER_BIT
				dstStage = vk.VK_PIPELINE_STAGE_FRAGMENT_SHADER
			else
				error "unsupported layout transition!"
			end

			vk.vkCmdPipelineBarrier(
				commandBuffer,	-- commandBuffer
				srcStage,       -- srcStageMask
				dstStage,       -- dstStageMask
				0,              -- dependencyFlags
				0,              -- memoryBarrierCount
				nil,            -- pMemoryBarriers
				0,              -- bufferMemoryBarrierCount
				nil,            -- pBufferMemoryBarriers
				1,              -- imageMemoryBarrierCount
				self.barrier	-- pImageMemoryBarriers
			)
			self.barrier = nil
		end
	)
end

function VulkanCommandPool:copyBuffer(srcBuffer, dstBuffer, size)
	VKSingleTimeCommand(
		self.device,
		self.graphicsQueue.id,
		self.id,
		function(commandBuffer)
			self.regions = VkBufferCopy()
			self.regions.size = size
			vk.vkCmdCopyBuffer(
				commandBuffer,
				srcBuffer.id,
				dstBuffer.id,
				1,
				self.regions
			)
			self.regions = nil
		end
	)
end

function VulkanCommandPool:copyBufferToImage(buffer, image, width, height)
	VKSingleTimeCommand(
		self.device,
		self.graphicsQueue.id,
		self.id,
		function(commandBuffer)
			self.regions = VkBufferImageCopy()
			self.regions.imageSubresource.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT
			self.regions.imageSubresource.layerCount = 1
			self.regions.imageExtent.width = width
			self.regions.imageExtent.height = height
			self.regions.imageExtent.depth = 1
			vk.vkCmdCopyBufferToImage(
				commandBuffer,
				buffer.id,
				image,
				vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
				1,
				self.regions
			)
			self.regions = nil
		end
	)
end

function VulkanCommandPool:destroy(device)
	if self.id then
		vk.vkDestroyCommandPool(device, self.id, nil)
	end
	self.id = nil
end

return VulkanCommandPool 
