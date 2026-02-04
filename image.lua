require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local vkResult = require 'vk.util'.vkResult
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkImage = ffi.typeof'VkImage'
local VkMemoryRequirements = ffi.typeof'VkMemoryRequirements'
local makeVkImageCreateInfo = makeStructCtor'VkImageCreateInfo'


local VKImage = class()

function VKImage:init(args)
	self.device = assert.index(args, 'device')
	args.device = nil

	args.imageType = args.imageType or vk.VK_IMAGE_TYPE_2D
	args.extent.depth = args.extent.depth or 1
	args.mipLevels = args.mipLevels or 1
	args.arrayLayers = args.arrayLayers or 1
	args.tiling = args.tiling or vk.VK_IMAGE_TILING_OPTIMAL
	args.sharingMode = args.sharingMode or vk.VK_SHARING_MODE_EXCLUSIVE
	args.initialLayout = args.initialLayout or vk.VK_IMAGE_LAYOUT_UNDEFINED

	self.id, self.idptr = vkGet(
		VkImage,
		vkassert,
		vk.vkCreateImage,
		self.device.id,
		makeVkImageCreateInfo(args),
		nil
	)

	-- same as VKBuffer
	if not args.dontMakeMem then
		local memReq = self:getMemReq()
		local mem = self.device:makeMem{
			allocationSize = memReq.size,
			memoryTypeIndex = args.physDev:findMemoryType(
				memReq.memoryTypeBits,
				args.memProps
			),
		}
		self.mem = mem

		assert(self:bindMemory(mem.id))
	end

	if not args.dontMakeView then
		self.view = self:makeView{
			viewType = vk.VK_IMAGE_VIEW_TYPE_2D,
			format = args.format,
			subresourceRange = {
				aspectMask = assert.index(args, 'aspectMask'),
				levelCount = args.mipLevels,
				layerCount = args.layerCount or 1,
			},
		}
	end
end

function VKImage:getMemReq()
	return vkGet(
		VkMemoryRequirements,
		nil,
		vk.vkGetImageMemoryRequirements,
		self.device.id,
		self.id
	)
end

function VKImage:bindMemory(mem)
	return vkResult(
		vk.vkBindImageMemory(
			self.device.id,
			self.id,
			mem,
			0
		),
		'vkBindImageMemory'
	)
end

function VKImage:destroy()
	if self.view then
		self.view:destroy()
	end
	self.view = nil

	if self.mem then
		self.mem:destroy()
	end
	self.mem = nil

	if self.id then
		vk.vkDestroyImage(self.device.id, self.id, nil)
	end
	self.id = nil
	self.idptr = nil
end

function VKImage:__gc()
	return self:destroy()
end

-- helper functions

function VKImage:makeView(args)
	args.device = self.device
	args.image = self.id
	local VKImageView = require 'vk.imageview'
	return self.device:addAutoDestroy(VKImageView(args))
end

function VKImage:makeMemBarrier(args, ...)
	args.image = self.id
	local VKCmdBuf = require 'vk.cmdbuf'
	return VKCmdBuf.makeVkImageMemoryBarrier(args, ...)
end

-- static
function VKImage:makeFromStaged(args)
	local staging = args.device:makeBuffer{
		size = args.size,
		usage = vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
		-- VKMemory:
		physDev = args.physDev,
		memProps = bit.bor(
			vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
			vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
		),
		data = args.data,
	}

	args.memProps = vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
	local image = VKImage(args)

	args.queue:transitionImageLayout(
		args.cmdPool,
		image.id,
		vk.VK_IMAGE_LAYOUT_UNDEFINED,
		vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
		args.mipLevels
	)

	args.queue:copyBufferToImage(
		args.cmdPool,
		staging,
		image.id,
		args.extent.width,
		args.extent.height
	)

	staging:destroy()

	-- rlly this should go in "makeTextureFromStaged" but I'm keeping it separate ...
	-- Vulkan is such a mess ...
	if args.generateMipmap then
		image:generateMipmap(args)
	end

	return image
end

function VKImage:generateMipmap(args)
	local image = self
	local physDev = args.physDev
	local texWidth = args.extent.width
	local texHeight = args.extent.height
	local mipLevels = args.mipLevels
	local aspectMask = args.aspectMask
	local formatProperties = physDev:getFormatProps(args.format)

	if 0 == bit.band(formatProperties.optimalTilingFeatures, vk.VK_FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_LINEAR_BIT) then
		error "texture image format does not support linear blitting!"
	end

	args.queue:singleTimeCommand(
		args.cmdPool,
		function(cmds)
			local barrier = image:makeMemBarrier{
				srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED,
				dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED,
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
					image.id,
					vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
					image.id,
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

return VKImage
