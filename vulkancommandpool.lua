require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local makeStructCtor = require 'vk.util'.makeStructCtor
local VKCommandPool = require 'vk.commandpool'


local VkBufferCopy = ffi.typeof'VkBufferCopy'
local VkBufferImageCopy = ffi.typeof'VkBufferImageCopy'


local makeVkImageMemoryBarrier = makeStructCtor'VkImageMemoryBarrier'


local VulkanCommandPool = class()

function VulkanCommandPool:init(common, physDev, device, surface)
	self.obj = VKCommandPool{
		device = device,
		flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
		queueFamilyIndex = assert.index(physDev:findQueueFamilies(nil, surface), 'graphicsFamily'),
	}
	self.graphicsQueue = common.graphicsQueue
end

function VulkanCommandPool:transitionImageLayout(image, oldLayout, newLayout, mipLevels)
	self.graphicsQueue:singleTimeCommand(
		self.obj,
		function(commandBuffer)
			local barrier = makeVkImageMemoryBarrier{
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
			}

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
				commandBuffer.id,	-- commandBuffer
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
	self.graphicsQueue:singleTimeCommand(
		self.obj,
		function(commandBuffer)
			vk.vkCmdCopyBuffer(
				commandBuffer.id,
				srcBuffer.id,
				dstBuffer.id,
				1,
				VkBufferCopy{
					size = size,
				}
			)
		end
	)
end

function VulkanCommandPool:copyBufferToImage(buffer, image, width, height)
	self.graphicsQueue:singleTimeCommand(
		self.obj,
		function(commandBuffer)
			vk.vkCmdCopyBufferToImage(
				commandBuffer.id,
				buffer.id,
				image,
				vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
				1,
				VkBufferImageCopy{
					imageSubresource = {
						aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
						layerCount = 1,
					},
					imageExtent = {
						width = width,
						height = height,
						depth = 1,
					},
				}
			)
		end
	)
end

function VulkanCommandPool:destroy()
	if self.obj then
		self.obj:destroy()
	end
	self.obj = nil
end

function VulkanCommandPool:__gc()
	return self:destroy()
end

return VulkanCommandPool 
