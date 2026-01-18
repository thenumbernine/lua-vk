require 'ext.gc'
local class = require 'ext.class'
local assert = require 'ext.assert'
local table = require 'ext.table'
local vk = require 'vk'
local VKImage = require 'vk.image'
local VKBuffer = require 'vk.buffer'
local VKMemory = require 'vk.memory'


local VulkanDeviceMemoryImage = class()

function VulkanDeviceMemoryImage:makeTextureFromStaged(args)
	if args.dontMakeView == nil then
		args.dontMakeView = true
	end

	local stagingBufferAndMemory = VKBuffer{
		device = args.device,
		size = args.bufferSize,
		usage = vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
		-- memory fields:
		physDev = args.physDev,
		memProps = bit.bor(
			vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
			vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
		),
		data = args.srcBuffer,
	}

	local image = VKImage{
		device = args.device,
		format = args.format,
		extent = {
			width = args.width,
			height = args.height,
			depth = 1,
		},
		mipLevels = args.mipLevels or 1,
		samples = vk.VK_SAMPLE_COUNT_1_BIT,
		usage = bit.bor(
			vk.VK_IMAGE_USAGE_TRANSFER_SRC_BIT,
			vk.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
			vk.VK_IMAGE_USAGE_SAMPLED_BIT
		),	
		-- memory:
		physDev = args.physDev,
		memProps = vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
		-- view
		aspectMask = args.aspectMask,
		dontMakeView = args.dontMakeView,
	}

	args.queue:transitionImageLayout(
		args.commandPool,
		image.id,
		vk.VK_IMAGE_LAYOUT_UNDEFINED,
		vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
		args.mipLevels
	)

	args.queue:copyBufferToImage(
		args.commandPool,
		stagingBufferAndMemory,
		image.id,
		args.width,
		args.height
	)

	stagingBufferAndMemory:destroy()

	-- rlly this should go in "makeTextureFromStaged" but I'm keeping it separate ...
	-- Vulkan is such a mess ...
	if args.generateMipmap then
		self:textureGenerateMipmap(
			table(args, {image = image.id})
			:setmetatable(nil)
		)
	end

	return setmetatable({
		device = args.device,
		image = image,
		imageMemory = image.mem,
		imageView = image.view,
	}, VulkanDeviceMemoryImage)
end

function VulkanDeviceMemoryImage:makeTextureFromStagedAndView(args)
	args.dontMakeView = false
	return self:makeTextureFromStaged(args)
end

function VulkanDeviceMemoryImage:textureGenerateMipmap(args)
	local physDev = args.physDev
	local image = args.image
	local texWidth = args.width
	local texHeight = args.height
	local mipLevels = args.mipLevels
	local aspectMask = args.aspectMask
	local formatProperties = physDev:getFormatProps(args.format)

	if 0 == bit.band(formatProperties.optimalTilingFeatures, vk.VK_FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_LINEAR_BIT) then
		error "texture image format does not support linear blitting!"
	end

	args.queue:singleTimeCommand(
		args.commandPool,
		function(cmds)
			local barrier = cmds.makeVkImageMemoryBarrier{
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
				cmds:pipelineBarrier(
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

				cmds:blitImage(
					image,
					vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
					image,
					vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
					1,
					cmds.VkImageBlit{
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
				cmds:pipelineBarrier(
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

			cmds:pipelineBarrier(
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
