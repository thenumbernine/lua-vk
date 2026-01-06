-- helper
local ffi = require 'ffi'
local class = require 'ext.class'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local VKSingleTimeCommand = require 'vk.singletimecommand'


local VkCommandPool = ffi.typeof'VkCommandPool'
local VkCommandPoolCreateInfo_1 = ffi.typeof'VkCommandPoolCreateInfo[1]'
local VkImageMemoryBarrier_1 = ffi.typeof'VkImageMemoryBarrier[1]'
local VkBufferCopy_1 = ffi.typeof'VkBufferCopy[1]'
local VkBufferImageCopy_1 = ffi.typeof'VkBufferImageCopy[1]'


local VulkanCommandPool = class()

function VulkanCommandPool:init(common, physDev, device, surface)
	local queueFamilyIndices = physDev:findQueueFamilies(nil, surface)

	self.info = ffi.new(VkCommandPoolCreateInfo_1, {{
		sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
		flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
		queueFamilyIndex = queueFamilyIndices.graphicsFamily,
	}})
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
			self.barrier = ffi.new(VkImageMemoryBarrier_1, {{
				oldLayout = oldLayout,
				newLayout = newLayout,
				srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED,
				dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED,
				image = image,
				subresourceRange = {
					aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
					levelCount = mipLevels,
					layerCount = 1,
				},
			}})

			local srcStage, dstStage
			if oldLayout == vk.VK_IMAGE_LAYOUT_UNDEFINED
			and newLayout == vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
			then
				self.barrier[0].srcAccessMask = 0
				self.barrier[0].dstAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT
				srcStage = vk.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT
				dstStage = vk.VK_PIPELINE_STAGE_TRANSFER_BIT
			elseif oldLayout == vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
			and newLayout == vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
			then
				self.barrier[0].srcAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT
				self.barrier[0].dstAccessMask = vk.VK_ACCESS_SHADER_READ_BIT
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
				self.barrier         -- pImageMemoryBarriers
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
			self.regions = ffi.new(VkBufferCopy_1)
			self.regions[0].size = size
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
			self.regions = ffi.new(VkBufferImageCopy_1, {{
				imageSubresource = {
					aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
					layerCount = 1,
				},
				imageExtent = {
					width = width,
					height = height,
					depth = 1,
				},
			}})
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

return VulkanCommandPool 
