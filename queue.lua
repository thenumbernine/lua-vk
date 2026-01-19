local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkGet = require 'vk.util'.vkGet
local vkResult = require 'vk.util'.vkResult
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkQueue = ffi.typeof'VkQueue'

local makeVkSubmitInfo = makeStructCtor(
	'VkSubmitInfo',
	{
		{
			name = 'waitDstStageMask',
			ptrname = 'pWaitDstStageMask',
			type = 'VkPipelineStageFlags[1]',
			notarray = true,
		},
		{
			name = 'commandBuffers',
			type = 'VkCommandBuffer',
		},
	}
)

local makeVkPresentInfoKHR = makeStructCtor(
	'VkPresentInfoKHR',
	{
		{
			name = 'swapchains',
			type = 'VkSwapchainKHR',
		},
		{
			name = 'waitSemaphores',
			type = 'VkSemaphore',
		},
	}
)



local VKQueue = class()

function VKQueue:init(args)
	self.device = assert.index(args, 'device')
	args.device = nil

	local queueFamilyIndex = assert.index(args, 'family')
	local queueIndex = args.index or 0

	self.id, self.idptr = vkGet(
		VkQueue,
		nil,
		vk.vkGetDeviceQueue,
		self.device.id,
		queueFamilyIndex,
		queueIndex
	)
end

VKQueue.makeVkSubmitInfo = makeVkSubmitInfo 
function VKQueue:submit(submitInfo, numInfo, fences)
	return vkResult(vk.vkQueueSubmit(
		self.id,
		numInfo or 1,
		submitInfo,
		fences
	), 'vkQueueSubmit')
end

function VKQueue:waitIdle()
	return vkResult(vk.vkQueueWaitIdle(self.id), 'vkQueueWaitIdle')
end

VKQueue.makeVkPresentInfoKHR = makeVkPresentInfoKHR 
function VKQueue:present(...)
	return vkResult(vk.vkQueuePresentKHR(self.id, ...), 'vkQueuePresentKHR')
end

-- helper functionality

function VKQueue:singleTimeCommand(commandPool, callback)
	local cmds = commandPool:makeCmds{
		level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
	}

	assert(cmds:begin(cmds.makeVkCommandBufferBeginInfo{
		flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
	}))

	callback(cmds)

	assert(cmds:done())

	assert(self:submit(
		makeVkSubmitInfo{
			-- don't use conversion field, just use the pointer
			commandBufferCount = 1,
			pCommandBuffers = cmds.idptr,
		}
	))

	assert(self:waitIdle())
	cmds:destroy()
end

-- I can't tell if these should be functions of command pool or queue

function VKQueue:transitionImageLayout(commandPool, image, oldLayout, newLayout, mipLevels)
	self:singleTimeCommand(
		commandPool,
		function(cmds)
			local barrier = cmds.makeVkImageMemoryBarrier{
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

			cmds:pipelineBarrier(
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

function VKQueue:copyBuffer(commandPool, srcBuffer, dstBuffer, size)
	self:singleTimeCommand(
		commandPool,
		function(cmds)
			cmds:copyBuffer(
				srcBuffer.id,
				dstBuffer.id,
				1,
				cmds.VkBufferCopy{
					size = size,
				}
			)
		end
	)
end

function VKQueue:copyBufferToImage(commandPool, buffer, image, width, height)
	self:singleTimeCommand(
		commandPool,
		function(cmds)
			cmds:copyBufferToImage(
				buffer.id,
				image,
				vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
				1,
				cmds.VkBufferImageCopy{
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

return VKQueue
