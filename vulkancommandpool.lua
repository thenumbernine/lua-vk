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

	local info = VkCommandPoolCreateInfo()
	info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
	info.flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT
	info.queueFamilyIndex = assert.index(queueFamilyIndices, 'graphicsFamily')
	self.id = vkGet(VkCommandPool, vkassert, vk.vkCreateCommandPool, device.obj.id, info, nil)

	self.device = device.obj.id
	self.graphicsQueue = common.graphicsQueue
end

function VulkanCommandPool:transitionImageLayout(image, oldLayout, newLayout, mipLevels)
	VKSingleTimeCommand(
		self.device,
		self.graphicsQueue.id,
		self.id,
		function(commandBuffer)
			local barrier = VkImageMemoryBarrier()
			barrier.sType = vk.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER
			barrier.oldLayout = oldLayout
			barrier.newLayout = newLayout
			barrier.srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED
			barrier.dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED
			barrier.image = image
			barrier.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT
			barrier.subresourceRange.levelCount = mipLevels
			barrier.subresourceRange.layerCount = 1

			local srcStage, dstStage
			if oldLayout == vk.VK_IMAGE_LAYOUT_UNDEFINED
			and newLayout == vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
			then
				barrier.srcAccessMask = 0
				barrier.dstAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT
				srcStage = vk.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT
				dstStage = vk.VK_PIPELINE_STAGE_TRANSFER_BIT
			elseif oldLayout == vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
			and newLayout == vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
			then
				barrier.srcAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT
				barrier.dstAccessMask = vk.VK_ACCESS_SHADER_READ_BIT
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
				barrier			-- pImageMemoryBarriers
			)
		end
	)
end

function VulkanCommandPool:copyBuffer(srcBuffer, dstBuffer, size)
	VKSingleTimeCommand(
		self.device,
		self.graphicsQueue.id,
		self.id,
		function(commandBuffer)
			local regions = VkBufferCopy()
			regions.size = size
			vk.vkCmdCopyBuffer(
				commandBuffer,
				srcBuffer.id,
				dstBuffer.id,
				1,
				regions
			)
		end
	)
end

function VulkanCommandPool:copyBufferToImage(buffer, image, width, height)
	VKSingleTimeCommand(
		self.device,
		self.graphicsQueue.id,
		self.id,
		function(commandBuffer)
			local regions = VkBufferImageCopy()
			regions.imageSubresource.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT
			regions.imageSubresource.layerCount = 1
			regions.imageExtent.width = width
			regions.imageExtent.height = height
			regions.imageExtent.depth = 1
			vk.vkCmdCopyBufferToImage(
				commandBuffer,
				buffer.id,
				image,
				vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
				1,
				regions
			)
		end
	)
end

function VulkanCommandPool:destroy(device)
	if self.id == nil then return end
	vk.vkDestroyCommandPool(device, self.id, nil)
	self.id = nil
end

return VulkanCommandPool 
