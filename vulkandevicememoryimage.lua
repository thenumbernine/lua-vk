require 'ext.gc'
local class = require 'ext.class'
local table = require 'ext.table'
local vk = require 'vk'
local VKImage = require 'vk.image'
local VKMemory = require 'vk.memory'
local VulkanDeviceMemoryFromStagingBuffer = require 'vk.vulkandevicememoryfromstagingbuffer'


local VulkanDeviceMemoryImage = class()

function VulkanDeviceMemoryImage:makeImage(args)
	local image = VKImage{
		device = args.device,
		imageType = vk.VK_IMAGE_TYPE_2D,
		format = args.format,
		extent = {
			width = args.width,
			height = args.height,
			depth = 1,
		},
		mipLevels = args.mipLevels or 1,
		arrayLayers = 1,
		samples = args.samples,
		tiling = args.tiling,
		usage = args.usage,
		sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
		initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED,
	}

	local memReq = image:getMemReq()
	local imageMemory = VKMemory{
		device = args.device,
		allocationSize = memReq.size,
		memoryTypeIndex = args.physDev:findMemoryType(
			memReq.memoryTypeBits,
			args.properties
		),
	}
	assert(image:bindMemory(imageMemory.id))

	return setmetatable({
		device = args.device,
		image = image,
		imageMemory = imageMemory,
	}, VulkanDeviceMemoryImage)
end

function VulkanDeviceMemoryImage:makeTextureFromStaged(args)
	local stagingBufferAndMemory = VulkanDeviceMemoryFromStagingBuffer:create(
		args.physDev,
		args.device,
		args.srcBuffer,
		args.bufferSize
	)

	local imageAndMemory = self:makeImage{
		physDev = args.physDev,
		device = args.device,
		width = args.width,
		height = args.height,
		mipLevels = args.mipLevels or 1,
		samples = vk.VK_SAMPLE_COUNT_1_BIT,
		format = args.format,
		tiling = vk.VK_IMAGE_TILING_OPTIMAL,
		usage = bit.bor(
			vk.VK_IMAGE_USAGE_TRANSFER_SRC_BIT,
			vk.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
			vk.VK_IMAGE_USAGE_SAMPLED_BIT
		),
		properties = vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
	}

	args.commandPool:transitionImageLayout(
		imageAndMemory.image.id,
		vk.VK_IMAGE_LAYOUT_UNDEFINED,
		vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
		args.mipLevels
	)

	args.commandPool:copyBufferToImage(
		stagingBufferAndMemory.buffer,
		imageAndMemory.image.id,
		args.width,
		args.height
	)

	stagingBufferAndMemory.memory:destroy()
	stagingBufferAndMemory.buffer:destroy()

	-- rlly this should go in "makeTextureFromStaged" but I'm keeping it separate ...
	-- Vulkan is such a mess ...
	if args.generateMipmap then
		self:textureGenerateMipmap(
			table(args, {image = imageAndMemory.image.id})
			:setmetatable(nil)
		)
	end

	return imageAndMemory
end

function VulkanDeviceMemoryImage:makeImageAndView(args)
	local image = self:makeImage(args)
	image.imageView = image.image:makeImageView{
		viewType = vk.VK_IMAGE_VIEW_TYPE_2D,
		format = args.format,
		subresourceRange = {
			aspectMask = args.aspectMask,
			levelCount = args.mipLevels or 1,
			layerCount = args.layerCount or 1,
		},
	}
	return image
end

function VulkanDeviceMemoryImage:makeTextureFromStagedAndView(args)
	local imageAndMemory = self:makeTextureFromStaged(args)

	imageAndMemory.imageView = imageAndMemory.image:makeImageView{
		viewType = vk.VK_IMAGE_VIEW_TYPE_2D,
		format = args.format,
		subresourceRange = {
			aspectMask = args.aspectMask,
			levelCount = args.mipLevels or 1,
			layerCount = args.layerCount or 1,
		},
	}
	return imageAndMemory
end

function VulkanDeviceMemoryImage:textureGenerateMipmap(args)
	local physDev = args.physDev
	local graphicsQueue = args.graphicsQueue
	local commandPool = args.commandPool
	local image = args.image
	local texWidth = args.width
	local texHeight = args.height
	local mipLevels = args.mipLevels
	local aspectMask = args.aspectMask
	local formatProperties = physDev:getFormatProps(args.format)

	if 0 == bit.band(formatProperties.optimalTilingFeatures, vk.VK_FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_LINEAR_BIT) then
		error "texture image format does not support linear blitting!"
	end

	graphicsQueue:singleTimeCommand(
		commandPool.obj,
		function(commandBuffer)
			local barrier = commandBuffer.makeVkImageMemoryBarrier{
				srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED,
				dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED,
				image = image,
				subresourceRange = {
					aspectMask = aspectMask,
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
							aspectMask = aspectMask,
							mipLevel = i-1,
							layerCount = 1,
						},
						srcOffsets = {
							{x=0, y=0, z=0},
							{x=mipWidth, y=mipHeight, z=1},
						},
						dstSubresource = {
							aspectMask = aspectMask,
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


function VulkanDeviceMemoryImage:destroy()
	if self.imageView then
		self.imageView:destroy()
	end
	self.imageView = nil
	
	if self.imageMemory then
		self.imageMemory:destroy()
	end
	self.imageMemory = nil

	if self.image then
		self.image:destroy()
	end
	self.image = nil
end

function VulkanDeviceMemoryImage:__gc()
	return self:destroy()
end

return VulkanDeviceMemoryImage
