local ffi = require 'ffi'
local range = require 'ext.range'
local table = require 'ext.table'
local timer = require 'ext.timer'
local assertne = require 'ext.assert'.ne
local asserteq = require 'ext.assert'.eq
local vec3f = require 'vec-ffi.vec3f'
local math = require 'ext.math'	-- clamp
local vk = require 'vk'
local vector = require 'ffi.cpp.vector-lua'
local matrix_ffi = require 'matrix.ffi'

local sdl = require 'sdl'
ffi.cdef[[
char const * const * SDL_Vulkan_GetInstanceExtensions(uint32_t * count);
]]


vk.VK_EXT_DEBUG_UTILS_EXTENSION_NAME = "VK_EXT_debug_utils"
vk.VK_KHR_SWAPCHAIN_EXTENSION_NAME = "VK_KHR_swapchain"
vk.VK_KHR_XLIB_SURFACE_EXTENSION_NAME = 'VK_KHR_xlib_surface'
vk.VK_KHR_SURFACE_EXTENSION_NAME = 'VK_KHR_surface'

-- TODO move to vk?

local function VK_MAKE_VERSION(major, minor, patch)
	return bit.bor(bit.lshift(major, 22), bit.lshift(minor, 12), patch)
end
local function VK_MAKE_API_VERSION(variant, major, minor, patch)
	return bit.bor(bit.lshift(variant, 29), bit.lshift(major, 22), bit.lshift(minor, 12), patch)
end

local VK_API_VERISON_1_0 = VK_MAKE_API_VERSION(0, 1, 0, 0)
-- but why not just use bitfields? meh

-- [[ vulkan namespace / class wrappers / idk
local class = require 'ext.class'
local path = require 'ext.path'
local struct = require 'struct'

local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local vkGetVector = require 'vk.util'.vkGetVector

-- how to distinguish between oop classes and ffi types?
local VkInstance = require 'vk.instance'
local VkDevice = require 'vk.device'
local VkBuffer = require 'vk.buffer'
local VKSwapchain = require 'vk.swapchain'
local VkSurface = require 'vk.surface'
local VkQueue = require 'vk.queue'


local VkAcquireNextImageInfoKHR_1 = ffi.typeof'VkAcquireNextImageInfoKHR[1]'
local VkApplicationInfo_1 = ffi.typeof'VkApplicationInfo[1]'
local VkAttachmentDescription = ffi.typeof'VkAttachmentDescription'
local VkAttachmentReference_1 = ffi.typeof'VkAttachmentReference[1]'
local VkBufferCopy_1 = ffi.typeof'VkBufferCopy[1]'
local VkBufferImageCopy_1 = ffi.typeof'VkBufferImageCopy[1]'
local VkBuffer_1 = ffi.typeof'VkBuffer[1]'
local VkClearValue = ffi.typeof'VkClearValue'
local VkCommandBuffer = ffi.typeof'VkCommandBuffer'
local VkCommandBufferAllocateInfo_1 = ffi.typeof'VkCommandBufferAllocateInfo[1]'
local VkCommandBufferBeginInfo_1 = ffi.typeof'VkCommandBufferBeginInfo[1]'
local VkCommandBuffer_1 = ffi.typeof'VkCommandBuffer[1]'
local VkCommandPool = ffi.typeof'VkCommandPool'
local VkCommandPoolCreateInfo_1 = ffi.typeof'VkCommandPoolCreateInfo[1]'
local VkDescriptorBufferInfo_1 = ffi.typeof'VkDescriptorBufferInfo[1]'
local VkDescriptorImageInfo_1 = ffi.typeof'VkDescriptorImageInfo[1]'
local VkDescriptorPool = ffi.typeof'VkDescriptorPool'
local VkDescriptorPoolCreateInfo_1 = ffi.typeof'VkDescriptorPoolCreateInfo[1]'
local VkDescriptorPoolSize = ffi.typeof'VkDescriptorPoolSize'
local VkDescriptorSet = ffi.typeof'VkDescriptorSet'
local VkDescriptorSetAllocateInfo_1 = ffi.typeof'VkDescriptorSetAllocateInfo[1]'
local VkDescriptorSetLayout = ffi.typeof'VkDescriptorSetLayout'
local VkDescriptorSetLayoutBinding = ffi.typeof'VkDescriptorSetLayoutBinding'
local VkDescriptorSetLayoutCreateInfo_1 = ffi.typeof'VkDescriptorSetLayoutCreateInfo[1]'
local VkDeviceMemory = ffi.typeof'VkDeviceMemory'
local VkDeviceQueueCreateInfo = ffi.typeof'VkDeviceQueueCreateInfo'
local VkDeviceSize_1 = ffi.typeof'VkDeviceSize[1]'
local VkDynamicState = ffi.typeof'VkDynamicState'
local VkExtent2D = ffi.typeof'VkExtent2D'
local VkFence = ffi.typeof'VkFence'
local VkFenceCreateInfo_1 = ffi.typeof'VkFenceCreateInfo[1]'
local VkFramebuffer = ffi.typeof'VkFramebuffer'
local VkFramebufferCreateInfo_1 = ffi.typeof'VkFramebufferCreateInfo[1]'
local VkGraphicsPipelineCreateInfo_1 = ffi.typeof'VkGraphicsPipelineCreateInfo[1]'
local VkImage = ffi.typeof'VkImage'
local VkImageBlit_1 = ffi.typeof'VkImageBlit[1]'
local VkImageCreateInfo_1 = ffi.typeof'VkImageCreateInfo[1]'
local VkImageMemoryBarrier_1 = ffi.typeof'VkImageMemoryBarrier[1]'
local VkImageView = ffi.typeof'VkImageView'
local VkImageViewCreateInfo_1 = ffi.typeof'VkImageViewCreateInfo[1]'
local VkLayerProperties = ffi.typeof'VkLayerProperties'
local VkMemoryAllocateInfo_1 = ffi.typeof'VkMemoryAllocateInfo[1]'
local VkMemoryRequirements = ffi.typeof'VkMemoryRequirements'
local VkPhysicalDeviceFeatures_1 = ffi.typeof'VkPhysicalDeviceFeatures[1]'
local VkPipeline = ffi.typeof'VkPipeline'
local VkPipelineColorBlendAttachmentState_1 = ffi.typeof'VkPipelineColorBlendAttachmentState[1]'
local VkPipelineColorBlendStateCreateInfo_1 = ffi.typeof'VkPipelineColorBlendStateCreateInfo[1]'
local VkPipelineDepthStencilStateCreateInfo_1 = ffi.typeof'VkPipelineDepthStencilStateCreateInfo[1]'
local VkPipelineDynamicStateCreateInfo_1 = ffi.typeof'VkPipelineDynamicStateCreateInfo[1]'
local VkPipelineInputAssemblyStateCreateInfo_1 = ffi.typeof'VkPipelineInputAssemblyStateCreateInfo[1]'
local VkPipelineLayout = ffi.typeof'VkPipelineLayout'
local VkPipelineLayoutCreateInfo_1 = ffi.typeof'VkPipelineLayoutCreateInfo[1]'
local VkPipelineMultisampleStateCreateInfo_1 = ffi.typeof'VkPipelineMultisampleStateCreateInfo[1]'
local VkPipelineRasterizationStateCreateInfo_1 = ffi.typeof'VkPipelineRasterizationStateCreateInfo[1]'
local VkPipelineShaderStageCreateInfo = ffi.typeof'VkPipelineShaderStageCreateInfo'
local VkPipelineStageFlags_1 = ffi.typeof'VkPipelineStageFlags[1]'
local VkPipelineVertexInputStateCreateInfo_1 = ffi.typeof'VkPipelineVertexInputStateCreateInfo[1]'
local VkPipelineViewportStateCreateInfo_1 = ffi.typeof'VkPipelineViewportStateCreateInfo[1]'
local VkPresentInfoKHR_1 = ffi.typeof'VkPresentInfoKHR[1]'
local VkRect2D_1 = ffi.typeof'VkRect2D[1]'
local VkRenderPass = ffi.typeof'VkRenderPass'
local VkRenderPassBeginInfo_1 = ffi.typeof'VkRenderPassBeginInfo[1]'
local VkRenderPassCreateInfo_1 = ffi.typeof'VkRenderPassCreateInfo[1]'
local VkSampler = ffi.typeof'VkSampler'
local VkSamplerCreateInfo_1 = ffi.typeof'VkSamplerCreateInfo[1]'
local VkSemaphore = ffi.typeof'VkSemaphore'
local VkSemaphoreCreateInfo_1 = ffi.typeof'VkSemaphoreCreateInfo[1]'
local VkShaderModule = ffi.typeof'VkShaderModule'
local VkShaderModuleCreateInfo_1 = ffi.typeof'VkShaderModuleCreateInfo[1]'
local VkSubmitInfo_1 = ffi.typeof'VkSubmitInfo[1]'
local VkSubpassDependency = ffi.typeof'VkSubpassDependency'
local VkSubpassDescription = ffi.typeof'VkSubpassDescription'
local VkSwapchainKHR_1 = ffi.typeof'VkSwapchainKHR[1]'
local VkVertexInputAttributeDescription = ffi.typeof'VkVertexInputAttributeDescription'
local VkVertexInputBindingDescription = ffi.typeof'VkVertexInputBindingDescription'
local VkViewport_1 = ffi.typeof'VkViewport[1]'
local VkWriteDescriptorSet = ffi.typeof'VkWriteDescriptorSet'
local char_const_ptr = ffi.typeof'char const *'
local float = ffi.typeof'float'
local uint32_t = ffi.typeof'uint32_t'
local uint32_t_1 = ffi.typeof'uint32_t[1]'
local uint32_t_ptr = ffi.typeof'uint32_t*'
local uint64_t = ffi.typeof'uint64_t'


local VulkanInstance = class()

function VulkanInstance:init(common)
	local app = common.app
	local enableValidationLayers = common.enableValidationLayers

	local layerProps = vkGetVector(VkLayerProperties, vkassert, vk.vkEnumerateInstanceLayerProperties)
	print'vulkan layers:'
	for i=0,#layerProps-1 do
		print('',
			ffi.string(layerProps.v[i].layerName, vk.VK_MAX_EXTENSION_NAME_SIZE),
			ffi.string(layerProps.v[i].description, vk.VK_MAX_DESCRIPTION_SIZE)
		)
	end

	local appInfo = ffi.new(VkApplicationInfo_1, {{
		sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
		pApplicationName = app.title,
		applicationVersion = VK_MAKE_API_VERSION(0, 1, 0, 0),
		pEngineName = "No Engine",
		engineVersion = VK_MAKE_API_VERSION(0, 1, 0, 0),
		apiVersion = VK_API_VERISON_1_0,
	}})

	local layerNames = vector(char_const_ptr)
	if enableValidationLayers then
		layerNames:emplace_back()[0] = 'VK_LAYER_KHRONOS_validation'
	end

	local extensions = self:getRequiredExtensions(common)

	self.obj = VkInstance{
		pApplicationInfo = appInfo,
		enabledLayerCount = #layerNames,
		ppEnabledLayerNames = layerNames.v,
		enabledExtensionCount = #extensions,
		ppEnabledExtensionNames = extensions.v,
	}
end

function VulkanInstance:getRequiredExtensions(common)
	local app = common.app
	local enableValidationLayers = common.enableValidationLayers

	--[[ SDL2?
	local function sdlvksafe(f, ...)
		asserteq(sdl.SDL_TRUE, f(...))
	end
	local extensions = vkGetVector('char const *', sdlvksafe, sdl.SDL_Vulkan_GetInstanceExtensions, app.window)
	--]]
	-- [[ SDL3
	local extensions = vector(char_const_ptr)
	do
		local count = ffi.new(uint32_t_1)
		local extstrs = assertne(sdl.SDL_Vulkan_GetInstanceExtensions(count), ffi.null)
		for i=1,count[0]-1 do
			extensions:push_back(extstrs[i])
		end
	end
	--]]

	print'vulkan extensions:'
	for i=0,#extensions-1 do
		print('', ffi.string(extensions.v[i]))
	end

	if enableValidationLayers then
		extensions:emplace_back()[0] = vk.VK_EXT_DEBUG_UTILS_EXTENSION_NAME
	end

-- TODO why do I have to manually insert this here?
extensions:emplace_back()[0] = vk.VK_KHR_SURFACE_EXTENSION_NAME 

	return extensions
end


local VulkanPhysicalDevice = class()

function VulkanPhysicalDevice:init(common, deviceExtensions)
	self.common = common
	local instance = common.instance
	local surface = common.surface

	local physDevs = instance.obj:getPhysDevs()
	print'devices:'
	for _,physDev in ipairs(physDevs) do
		local props = physDev:getProps()
		print('',
			ffi.string(props.deviceName)
			..' type='..tostring(props.deviceType)
		)
	end

	for _,physDev in ipairs(physDevs) do
		if self:isDeviceSuitable(physDev, surface, deviceExtensions) then
			self.obj = physDev
			return
		end
	end

	error "failed to find a suitable GPU"
end

-- static method
function VulkanPhysicalDevice:isDeviceSuitable(physDev, surface, deviceExtensions)
	local indices = self:findQueueFamilies(physDev, surface)
	local extensionsSupported = self:checkDeviceExtensionSupport(physDev, deviceExtensions)
	local swapChainAdequate
	if extensionsSupported then
		local swapChainSupport = self:querySwapChainSupport(physDev, surface)
		swapChainAdequate = #swapChainSupport.formats > 0 and #swapChainSupport.presentModes > 0
	end

	local features = physDev:getFeatures()
	return indices
		and extensionsSupported
		and swapChainAdequate
		and features.samplerAnisotropy ~= 0
end

-- static method
function VulkanPhysicalDevice:findQueueFamilies(physDev, surface)
	physDev = physDev or self.obj
	assert(physDev, "you must either call this as a member method or as a static method while passing a physDev")
	local indices = {}
	local queueFamilies = physDev:getQueueFamilyProperties()
--print('queueFamilies queueFlags', require 'ext.tolua'(queueFamilies:totable():mapi(function(f) return f.queueFlags end)))
	for i=0,#queueFamilies-1 do
		local f = queueFamilies.v[i]
		if 0 ~= bit.band(f.queueFlags, vk.VK_QUEUE_GRAPHICS_BIT) then
--print('index',i,'has VK_QUEUE_GRAPHICS_BIT')
			indices.graphicsFamily = i
		end

		if physDev:getSurfaceSupport(i, surface) then
--print('index', i, 'has surface support')
			indices.presentFamily = i
--		else
--print('index', i, 'does not have surface support')
		end

		if indices.graphicsFamily and indices.presentFamily then
			return indices
		end
	end
	error "couldn't find all indices"
end

-- static method
function VulkanPhysicalDevice:checkDeviceExtensionSupport(physDev, deviceExtensions)
	local requiredExtensions = deviceExtensions:totable():mapi(function(v)
		return true, ffi.string(v)
	end):setmetatable(nil)

	local physDevExts = physDev:getExtProps()
	for i=0,#physDevExts-1 do
		requiredExtensions[ffi.string(physDevExts.v[i].extensionName)] = nil
	end
	return next(requiredExtensions) == nil
end

-- static method
function VulkanPhysicalDevice:querySwapChainSupport(physDev, surface)
	physDev = physDev or self.obj
	return {
		capabilities = physDev:getSurfaceCapabilities(surface),
		formats = physDev:getSurfaceFormats(surface),
		presentModes = physDev:getSurfacePresentModes(surface),
	}
end

function VulkanPhysicalDevice:getMaxUsableSampleCount(...)
	local props = self.obj:getProps(...)
	local counts = bit.band(props.limits.framebufferColorSampleCounts, props.limits.framebufferDepthSampleCounts)
	if 0 ~= bit.band(counts, vk.VK_SAMPLE_COUNT_64_BIT) then return vk.VK_SAMPLE_COUNT_64_BIT end
	if 0 ~= bit.band(counts, vk.VK_SAMPLE_COUNT_32_BIT) then return vk.VK_SAMPLE_COUNT_32_BIT end
	if 0 ~= bit.band(counts, vk.VK_SAMPLE_COUNT_16_BIT) then return vk.VK_SAMPLE_COUNT_16_BIT end
	if 0 ~= bit.band(counts, vk.VK_SAMPLE_COUNT_8_BIT) then return vk.VK_SAMPLE_COUNT_8_BIT end
	if 0 ~= bit.band(counts, vk.VK_SAMPLE_COUNT_4_BIT) then return vk.VK_SAMPLE_COUNT_4_BIT end
	if 0 ~= bit.band(counts, vk.VK_SAMPLE_COUNT_2_BIT) then return vk.VK_SAMPLE_COUNT_2_BIT end
	return vk.VK_SAMPLE_COUNT_1_BIT
end

function VulkanPhysicalDevice:findDepthFormat()
	return self:findSupportedFormat(
		{
			vk.VK_FORMAT_D32_SFLOAT,
			vk.VK_FORMAT_D32_SFLOAT_S8_UINT,
			vk.VK_FORMAT_D24_UNORM_S8_UINT,
		},
		vk.VK_IMAGE_TILING_OPTIMAL,
		vk.VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT
	)
end

function VulkanPhysicalDevice:findSupportedFormat(candidates, tiling, features)
	for _,format in ipairs(candidates) do
		local props = self.obj:getFormatProps(format)
		if tiling == vk.VK_IMAGE_TILING_LINEAR
		and bit.band(props.linearTilingFeatures, features) == features
		then
			return format
		elseif tiling == vk.VK_IMAGE_TILING_OPTIMAL
		and bit.band(props.optimalTilingFeatures, features) == features
		then
			return format
		end
	end
	error "failed to find supported format!"
end

function VulkanPhysicalDevice:findMemoryType(mask, props)
	local memProps = self.obj:getMemProps()
	for i=0,memProps.memoryTypeCount-1 do
		if bit.band(mask, bit.lshift(1, i)) ~= 0
		and bit.band(memProps.memoryTypes[i].propertyFlags, props) ~= 0
		then
			return i
		end
	end
	error "failed to find suitable memory type!"
end



local validationLayer = 'VK_LAYER_KHRONOS_validation'	-- TODO vector?

local VulkanDevice = class()

function VulkanDevice:init(physDev, deviceExtensions, enableValidationLayers, indices)
	local queuePriorities = vector(float)
	queuePriorities:emplace_back()[0] = 1
	local queueCreateInfos = vector(VkDeviceQueueCreateInfo)
	for queueFamily in pairs{
		[indices.graphicsFamily] = true,
		[indices.presentFamily] = true,
	} do
		local info = queueCreateInfos:emplace_back()
		info[0].sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
		info[0].queueFamilyIndex = queueFamily
		info[0].queueCount = #queuePriorities
		info[0].pQueuePriorities = queuePriorities.v
	end

	local deviceFeatures = ffi.new(VkPhysicalDeviceFeatures_1)
	deviceFeatures[0].samplerAnisotropy = vk.VK_TRUE

	local thisValidationLayers = vector(char_const_ptr)
	if enableValidationLayers then
		thisValidationLayers.emplace_back()[0] = validationLayer	-- TODO vector copy?
	end

	self.obj = VkDevice{
		-- create extra args:
		physDev = physDev,
		-- info args:
		queueCreateInfoCount = #queueCreateInfos,
		pQueueCreateInfos = queueCreateInfos.v,
		enabledLayerCount = #thisValidationLayers,
		ppEnabledLayerNames = thisValidationLayers.v,
		enabledExtensionCount = #deviceExtensions,
		ppEnabledExtensionNames = deviceExtensions.v,
		pEnabledFeatures = deviceFeatures,
	}
end


local VulkanDeviceMemoryFromStagingBuffer = class()

function VulkanDeviceMemoryFromStagingBuffer:create(physDev, device, srcData, bufferSize)
	local buffer = VkBuffer{
		device = device,
		size = bufferSize,
		usage = vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
		sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
	}

	local memReq = vkGet(VkMemoryRequirements, nil, vk.vkGetBufferMemoryRequirements, device, buffer.id)

	local info = ffi.new(VkMemoryAllocateInfo_1)
	info[0].allocationSize = memReq.size
	info[0].memoryTypeIndex = physDev:findMemoryType(memReq.memoryTypeBits, bit.bor(vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT, vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT))
	local memory = vkGet(VkDeviceMemory, vkassert, vk.vkAllocateMemory, device, info, nil)

	vkassert(vk.vkBindBufferMemory, device, buffer.id, memory, 0)

	local dstData = vkGet('void*', vkassert, vk.vkMapMemory, device, memory, 0, bufferSize, 0)
	ffi.copy(dstData, srcData, bufferSize)

	vk.vkUnmapMemory(device, memory)

	return {
		buffer = buffer,
		memory = memory,
	}
end


local VulkanDeviceMemoryImage = class()

function VulkanDeviceMemoryImage:createImage(
	physDev,
	device,
	width,
	height,
	mipLevels,
	numSamples,
	format,
	tiling,
	usage,
	properties
)
	local info = ffi.new(VkImageCreateInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO
	info[0].imageType = vk.VK_IMAGE_TYPE_2D
	info[0].format = format
	info[0].extent.width = width
	info[0].extent.height = height
	info[0].extent.depth = 1
	info[0].mipLevels = mipLevels
	info[0].arrayLayers = 1
	info[0].samples = numSamples
	info[0].tiling = tiling
	info[0].usage = usage
	info[0].sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE
	info[0].initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED
	local image = vkGet(VkImage, vkassert, vk.vkCreateImage, device, info, nil)

	local memReq = vkGet(VkMemoryRequirements, nil, vk.vkGetImageMemoryRequirements, device, image)

	local info = ffi.new(VkMemoryAllocateInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO
	info[0].allocationSize = memReq.size
	info[0].memoryTypeIndex = physDev:findMemoryType(memReq.memoryTypeBits, properties)
	local imageMemory = vkGet(VkDeviceMemory, vkassert, vk.vkAllocateMemory, device, info, nil)
	vkassert(vk.vkBindImageMemory, device, image, imageMemory, 0)

	return {image=image, imageMemory=imageMemory}
end

function VulkanDeviceMemoryImage:makeTextureFromStaged(
	physDev,
	device,
	commandPool,
	srcData,
	bufferSize,
	texWidth,
	texHeight,
	mipLevels
)
	local stagingBufferAndMemory = VulkanDeviceMemoryFromStagingBuffer:create(
		physDev,
		device,
		srcData,
		bufferSize
	)

	local imageAndMemory = self:createImage(physDev,
		device,
		texWidth,
		texHeight,
		mipLevels,
		vk.VK_SAMPLE_COUNT_1_BIT,
		vk.VK_FORMAT_R8G8B8A8_SRGB,
		vk.VK_IMAGE_TILING_OPTIMAL,
		bit.bor(vk.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
			vk.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
			vk.VK_IMAGE_USAGE_SAMPLED_BIT),
		vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
	)

	commandPool:transitionImageLayout(
		imageAndMemory.image,
		vk.VK_IMAGE_LAYOUT_UNDEFINED,
		vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
		mipLevels
	)

	commandPool:copyBufferToImage(
		stagingBufferAndMemory.buffer,
		imageAndMemory.image,
		texWidth,
		texHeight
	)

	stagingBufferAndMemory.buffer:destroy()

	return imageAndMemory
end

local VulkanSwapchain = class()

function VulkanSwapchain:init(width, height, physDev, device, surface, msaaSamples)
	self.width = width
	self.height = height

	local swapChainSupport = physDev:querySwapChainSupport(nil, surface)
	self.extent = self:chooseSwapExtent(width, height, swapChainSupport.capabilities)

	local imageCount = swapChainSupport.capabilities.minImageCount + 1
	if swapChainSupport.capabilities.maxImageCount > 0 then
		imageCount = math.min(imageCount, swapChainSupport.capabilities.maxImageCount)
	end

	local surfaceFormat = self:chooseSwapSurfaceFormat(swapChainSupport.formats)
	local presentMode = self:chooseSwapPresentMode(swapChainSupport.presentModes)

	local info = {}
	info.surface = surface.id
	info.minImageCount = imageCount
	info.imageFormat = surfaceFormat.format
	info.imageColorSpace = surfaceFormat.colorSpace
	info.imageExtent = self.extent
	info.imageArrayLayers = 1
	info.imageUsage = vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT
	info.preTransform = swapChainSupport.capabilities.currentTransform
	info.compositeAlpha = vk.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR
	info.presentMode = presentMode
	info.clipped = vk.VK_TRUE
	local indices = physDev:findQueueFamilies(nil, surface)
	local queueFamilyIndices = vector(uint32_t)
	for index in pairs{
		[indices.graphicsFamily] = true,
		[indices.presentFamily] = true,
	} do
		queueFamilyIndices:emplace_back()[0] = index
	end
	if indices.graphicsFamily ~= indices.presentFamily then
		info.imageSharingMode = vk.VK_SHARING_MODE_CONCURRENT
		info.queueFamilyIndexCount = #queueFamilyIndices
		info.pQueueFamilyIndices = queueFamilyIndices.v
	else
		info.imageSharingMode = vk.VK_SHARING_MODE_EXCLUSIVE
	end
	info.device = device
print('info.device.id', info.device.id)
	self.obj = VKSwapchain(info)

	self.images = self.obj:getImages(device)

	self.imageViews = vector(VkImageView)
	for i=0,#self.images-1 do
		self.imageViews:emplace_back()[0] = self:createImageView(
			device.id,
			self.images.v[i],
			surfaceFormat.format,
			vk.VK_IMAGE_ASPECT_COLOR_BIT,
			1)
	end

	self.renderPass = self:createRenderPass(physDev, device.id, surfaceFormat.format, msaaSamples)

	local colorFormat = surfaceFormat.format

	self.colorImageAndMemory = VulkanDeviceMemoryImage:createImage(
		physDev,
		device.id,
		width,
		height,
		1,
		msaaSamples,
		colorFormat,
		vk.VK_IMAGE_TILING_OPTIMAL,
		bit.bor(vk.VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT, vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT),
		vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
	)

	self.colorImageView = self:createImageView(
		device.id,
		self.colorImageAndMemory.image,
		colorFormat,
		vk.VK_IMAGE_ASPECT_COLOR_BIT,
		1
	)

	local depthFormat = physDev:findDepthFormat()

	self.depthImageAndMemory = VulkanDeviceMemoryImage:createImage(
		physDev,
		device.id,
		width,
		height,
		1,
		msaaSamples,
		depthFormat,
		vk.VK_IMAGE_TILING_OPTIMAL,
		vk.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
		vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
	)
	self.depthImageView = self:createImageView(
		device.id,
		self.depthImageAndMemory.image,
		depthFormat,
		vk.VK_IMAGE_ASPECT_DEPTH_BIT,
		1
	)

	self.framebuffers = vector(VkFramebuffer)
	for i=0,#self.imageViews-1 do
		local attachments = vector(VkImageView)
		attachments:push_back(self.colorImageView)
		attachments:push_back(self.depthImageView)
		attachments:push_back(self.imageViews.v[i])
		local info = ffi.new(VkFramebufferCreateInfo_1)
		info[0].sType = vk.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO
		info[0].renderPass = self.renderPass
		info[0].attachmentCount = #attachments
		info[0].pAttachments = attachments.v
		info[0].width = width
		info[0].height = height
		info[0].layers = 1
		self.framebuffers:push_back(vkGet(VkFramebuffer, vkassert, vk.vkCreateFramebuffer, device.id, info, nil))
	end
end

function VulkanSwapchain:chooseSwapExtent(width, height, capabilities)
	if capabilities.currentExtent.width ~= -1 then
		return ffi.new(VkExtent2D, capabilities.currentExtent)
	else
		local actualExtent = ffi.new(VkExtent2D, width, height)
		actualExtent.width = math.clamp(actualExtent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width)
		actualExtent.height = math.clamp(actualExtent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height)
		return actualExtent
	end
end

function VulkanSwapchain:chooseSwapSurfaceFormat(availableFormats)
	for i=0,#availableFormats-1 do
		local format = availableFormats.v[i]
		if format.format == vk.VK_FORMAT_B8G8R8A8_SRGB
		and format.colorSpace == vk.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR
		then
			return format
		end
	end
	return availableFormats[0]
end

function VulkanSwapchain:chooseSwapPresentMode(availablePresentModes)
	-- return-if-found ... why not just treat this as a set?
	for i=0,#availablePresentModes-1 do
		local presentMode = availablePresentModes.v[i]
		if presentMode == vk.VK_PRESENT_MODE_MAILBOX_KHR then
			return presentMode
		end
	end
	return vk.VK_PRESENT_MODE_FIFO_KHR
end

function VulkanSwapchain:createImageView(device, image, format, aspectFlags, mipLevels)
	local info = ffi.new(VkImageViewCreateInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
	info[0].image = image
	info[0].viewType = vk.VK_IMAGE_VIEW_TYPE_2D
	info[0].format = format
	info[0].subresourceRange.aspectMask = aspectFlags
	info[0].subresourceRange.levelCount = mipLevels
	info[0].subresourceRange.layerCount = 1
	return vkGet(VkImageView, vkassert, vk.vkCreateImageView, device, info, nil)
end

function VulkanSwapchain:createRenderPass(physDev, device, swapChainImageFormat, msaaSamples)
	local attachments = vector(VkAttachmentDescription)
	-- colorAttachment
	local a = attachments:emplace_back()
	a[0].format = swapChainImageFormat
	a[0].samples = msaaSamples
	a[0].loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR
	a[0].storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE
	a[0].stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE
	a[0].stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE
	a[0].initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED
	a[0].finalLayout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
	-- depthAttachment
	local a = attachments:emplace_back()
	a[0].format = physDev:findDepthFormat()
	a[0].samples = msaaSamples
	a[0].loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR
	a[0].storeOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE
	a[0].stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE
	a[0].stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE
	a[0].initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED
	a[0].finalLayout = vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL
	-- colorAttachmentResolve
	local a = attachments:emplace_back()
	a[0].format = swapChainImageFormat
	a[0].samples = vk.VK_SAMPLE_COUNT_1_BIT
	a[0].loadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE
	a[0].storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE
	a[0].stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE
	a[0].stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE
	a[0].initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED
	a[0].finalLayout = vk.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR

	local colorAttachmentRef = ffi.new(VkAttachmentReference_1)
	colorAttachmentRef[0].attachment = 0
	colorAttachmentRef[0].layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
	local depthAttachmentRef = ffi.new(VkAttachmentReference_1)
	depthAttachmentRef[0].attachment = 1
	depthAttachmentRef[0].layout = vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL
	local colorAttachmentResolveRef = ffi.new(VkAttachmentReference_1)
	colorAttachmentResolveRef[0].attachment = 2
	colorAttachmentResolveRef[0].layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL

	local subpasses = vector(VkSubpassDescription)
	local s = subpasses:emplace_back()
	s[0].pipelineBindPoint = vk.VK_PIPELINE_BIND_POINT_GRAPHICS
	s[0].colorAttachmentCount = 1
	s[0].pColorAttachments = colorAttachmentRef
	s[0].pResolveAttachments = colorAttachmentResolveRef
	s[0].pDepthStencilAttachment = depthAttachmentRef

	local dependencies = vector(VkSubpassDependency)
	local d = dependencies:emplace_back()
	d[0].srcSubpass = vk.VK_SUBPASS_EXTERNAL
	d[0].dstSubpass = 0
	d[0].srcStageMask = bit.bor(
		vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
		vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT
	)
	d[0].dstStageMask = bit.bor(
		vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
		vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT
	)
	d[0].srcAccessMask = 0
	d[0].dstAccessMask = bit.bor(
		vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
		vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT
	)

	local info = ffi.new(VkRenderPassCreateInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO
	info[0].attachmentCount = #attachments
	info[0].pAttachments = attachments.v
	info[0].subpassCount = #subpasses
	info[0].pSubpasses = subpasses.v
	info[0].dependencyCount = #dependencies
	info[0].pDependencies = dependencies.v
	return vkGet(VkRenderPass, vkassert, vk.vkCreateRenderPass, device, info, nil)
end


local VulkanShaderModule = class()

-- TODO lua.make here
-- glslangValidator -V shader.vert -o shader-vert.spv
-- glslangValidator -V shader.frag -o shader-frag.spv
function VulkanShaderModule:fromFile(device, filename)
	local code = assert(path(filename):read())
	local info = ffi.new(VkShaderModuleCreateInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO
	info[0].codeSize = #code
	info[0].pCode = ffi.cast(uint32_t_ptr, ffi.cast(char_const_ptr, code))
	return vkGet(VkShaderModule, vkassert, vk.vkCreateShaderModule, device, info, nil)
end

local Vertex = struct{
	name = 'Vertex',
	fields = {
		{name = 'pos', type = 'vec3f_t'},
		{name = 'color', type = 'vec3f_t'},
		{name = 'texCoord', type = 'vec3f_t'},
	},
	metatable = function(mt)
		mt.getBindingDescription = function()
			local d = ffi.new(VkVertexInputBindingDescription)
			d.binding = 0
			d.stride = ffi.sizeof'Vertex'
			d.inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX
			return d
		end

		mt.getAttributeDescriptions = function()
			local ar = vector(VkVertexInputAttributeDescription)

			local a = ar:emplace_back()
			a[0].location = 0
			a[0].binding = 0
			a[0].format = vk.VK_FORMAT_R32G32B32_SFLOAT
			a[0].offset = ffi.offsetof('Vertex', 'pos')

			local a = ar:emplace_back()
			a[0].location = 1
			a[0].binding = 0
			a[0].format = vk.VK_FORMAT_R32G32B32_SFLOAT
			a[0].offset = ffi.offsetof('Vertex', 'color')

			local a = ar:emplace_back()
			a[0].location = 2
			a[0].binding = 0
			a[0].format = vk.VK_FORMAT_R32G32B32_SFLOAT
			a[0].offset = ffi.offsetof('Vertex', 'texCoord')

			return ar
		end
	end,
}

local UniformBufferObject = struct{
	name = 'UniformBufferObject',
	fields = {
		{name = 'model', type = 'float[16]'},
		{name = 'view', type = 'float[16]'},
		{name = 'proj', type = 'float[16]'},
	},
}
asserteq(ffi.sizeof'UniformBufferObject', 4 * 4 * ffi.sizeof'float' * 3)

local VulkanGraphicsPipeline = class()

function VulkanGraphicsPipeline:init(physDev, device, renderPass, msaaSamples)
	-- descriptorSetLayout is only used by graphicsPipeline
	local bindings = vector(VkDescriptorSetLayoutBinding)

	--uboLayoutBinding
	local b = bindings:emplace_back()
	b[0].binding = 0
	b[0].descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
	b[0].descriptorCount = 1
	b[0].stageFlags = vk.VK_SHADER_STAGE_VERTEX_BIT

	--samplerLayoutBinding
	local b = bindings:emplace_back()
	b[0].binding = 1
	b[0].descriptorType = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
	b[0].descriptorCount = 1
	b[0].stageFlags = vk.VK_SHADER_STAGE_FRAGMENT_BIT

	local info = ffi.new(VkDescriptorSetLayoutCreateInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO
	info[0].bindingCount = #bindings
	info[0].pBindings = bindings.v
	self.descriptorSetLayout = vkGet(VkDescriptorSetLayout, nil, vk.vkCreateDescriptorSetLayout, device, info, nil)

	local vertShaderModule = VulkanShaderModule:fromFile(device, "shader-vert.spv")
	local fragShaderModule = VulkanShaderModule:fromFile(device, "shader-frag.spv")

	local bindingDescriptions = vector(VkVertexInputBindingDescription)
	bindingDescriptions:push_back(Vertex:getBindingDescription())

	local attributeDescriptions = Vertex:getAttributeDescriptions();
	local vertexInputInfo = ffi.new(VkPipelineVertexInputStateCreateInfo_1)
	vertexInputInfo[0].sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
	vertexInputInfo[0].vertexBindingDescriptionCount = #bindingDescriptions
	vertexInputInfo[0].pVertexBindingDescriptions = bindingDescriptions.v
	vertexInputInfo[0].vertexAttributeDescriptionCount = #attributeDescriptions
	vertexInputInfo[0].pVertexAttributeDescriptions = attributeDescriptions.v

	local inputAssembly = ffi.new(VkPipelineInputAssemblyStateCreateInfo_1)
	inputAssembly[0].topology = vk.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
	inputAssembly[0].primitiveRestartEnable = vk.VK_FALSE

	local viewportState = ffi.new(VkPipelineViewportStateCreateInfo_1)
	viewportState[0].viewportCount = 1
	viewportState[0].scissorCount = 1

	local rasterizer = ffi.new(VkPipelineRasterizationStateCreateInfo_1)
	rasterizer[0].depthClampEnable = vk.VK_FALSE
	rasterizer[0].rasterizerDiscardEnable = vk.VK_FALSE
	rasterizer[0].polygonMode = vk.VK_POLYGON_MODE_FILL
	--rasterizer[0].cullMode = vk::CullModeFlagBits::eBack,
	--rasterizer[0].frontFace = vk::FrontFace::eClockwise,
	--rasterizer[0].frontFace = vk::FrontFace::eCounterClockwise,
	rasterizer[0].depthBiasEnable = vk.VK_FALSE
	rasterizer[0].lineWidth = 1

	local multisampling = ffi.new(VkPipelineMultisampleStateCreateInfo_1)
	multisampling[0].rasterizationSamples = msaaSamples
	multisampling[0].sampleShadingEnable = vk.VK_FALSE

	local depthStencil = ffi.new(VkPipelineDepthStencilStateCreateInfo_1)
	depthStencil[0].depthTestEnable = vk.VK_TRUE
	depthStencil[0].depthWriteEnable = vk.VK_TRUE
	depthStencil[0].depthCompareOp = vk.VK_COMPARE_OP_LESS
	depthStencil[0].depthBoundsTestEnable = vk.VK_FALSE
	depthStencil[0].stencilTestEnable = vk.VK_FALSE

	local colorBlendAttachment = ffi.new(VkPipelineColorBlendAttachmentState_1)
	colorBlendAttachment[0].blendEnable = vk.VK_FALSE
	colorBlendAttachment[0].colorWriteMask = bit.bor(
		vk.VK_COLOR_COMPONENT_R_BIT,
		vk.VK_COLOR_COMPONENT_G_BIT,
		vk.VK_COLOR_COMPONENT_B_BIT,
		vk.VK_COLOR_COMPONENT_A_BIT
	)

	local colorBlending = ffi.new(VkPipelineColorBlendStateCreateInfo_1)
	colorBlending[0].logicOpEnable = vk.VK_FALSE
	colorBlending[0].logicOp = vk.VK_LOGIC_OP_COPY
	colorBlending[0].attachmentCount = 1
	colorBlending[0].pAttachments = colorBlendAttachment
	colorBlending[0].blendConstants[0] = 0
	colorBlending[0].blendConstants[1] = 0
	colorBlending[0].blendConstants[2] = 0
	colorBlending[0].blendConstants[3] = 0

	local dynamicStates = vector(VkDynamicState)
	dynamicStates:push_back(vk.VK_DYNAMIC_STATE_VIEWPORT)
	dynamicStates:push_back(vk.VK_DYNAMIC_STATE_SCISSOR)

	local dynamicState = ffi.new(VkPipelineDynamicStateCreateInfo_1)
	dynamicState[0].dynamicStateCount = #dynamicStates
	dynamicState[0].pDynamicStates = dynamicStates.v

	local descriptorSetLayouts = vector(VkDescriptorSetLayout)
	descriptorSetLayouts:push_back(self.descriptorSetLayout)

	local info = ffi.new(VkPipelineLayoutCreateInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
	info[0].setLayoutCount = #descriptorSetLayouts
	info[0].pSetLayouts = descriptorSetLayouts.v
	local pipelineLayout = vkGet(VkPipelineLayout, vkassert, vk.vkCreatePipelineLayout, device, info, nil)

	local shaderStages = vector(VkPipelineShaderStageCreateInfo)

	local s = shaderStages:emplace_back()
	s[0].sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
	s[0].stage = vk.VK_SHADER_STAGE_VERTEX_BIT
	s[0].module = vertShaderModule
	s[0].pName = 'main'	--'vert'	--GLSL uses 'main', but clspv doesn't allow 'main', so ...

	local s = shaderStages:emplace_back()
	s[0].sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
	s[0].stage = vk.VK_SHADER_STAGE_FRAGMENT_BIT
	s[0].module = fragShaderModule
	s[0].pName = 'main'	--'frag'

	local info = ffi.new(VkGraphicsPipelineCreateInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO
	info[0].stageCount = #shaderStages
	info[0].pStages = shaderStages.v
	info[0].pVertexInputState = vertexInputInfo	--why it need to be a pointer?
	info[0].pInputAssemblyState = inputAssembly
	info[0].pViewportState = viewportState
	info[0].pRasterizationState = rasterizer
	info[0].pMultisampleState = multisampling
	info[0].pDepthStencilState = depthStencil
	info[0].pColorBlendState = colorBlending
	info[0].pDynamicState = dynamicState
	info[0].layout = pipelineLayout
	info[0].renderPass = renderPass
	info[0].subpass = 0

	--info[0].basePipelineHandle = {}
	self.id = vkGet(VkPipeline, vkassert, vk.vkCreateGraphicsPipelines, device, nil, 1, info, nil)
end


function VKSingleTimeCommand(device, queue, commandPool, callback)
	local info = ffi.new(VkCommandBufferAllocateInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
	info[0].commandPool = commandPool
	info[0].level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY
	info[0].commandBufferCount = 1
	--[[
	local cmds = vkGet(VkCommandBuffer, vkassert, vk.vkAllocateCommandBuffers, device, info)
	--]]
	-- [[ I want to keep the pointer so ...
	local cmds = ffi.new(VkCommandBuffer_1)
	vkassert(vk.vkAllocateCommandBuffers, device, info, cmds)
	--]]

	local info = ffi.new(VkCommandBufferBeginInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
	info[0].flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT
	vkassert(vk.vkBeginCommandBuffer, cmds[0], info)

	callback(cmds[0])

	vkassert(vk.vkEndCommandBuffer, cmds[0])

	local submits = ffi.new(VkSubmitInfo_1)
	submits[0].sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO
	submits[0].commandBufferCount = 1
	submits[0].pCommandBuffers = cmds
	vkassert(vk.vkQueueSubmit, queue, 1, submits, nil)
	vkassert(vk.vkQueueWaitIdle, queue)
end


local VulkanCommandPool = class()

function VulkanCommandPool:init(common, physDev, device, surface)
	local queueFamilyIndices = physDev:findQueueFamilies(nil, surface)

	local info = ffi.new(VkCommandPoolCreateInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
	info[0].flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT
	info[0].queueFamilyIndex = queueFamilyIndices.graphicsFamily
	self.id = vkGet(VkCommandPool, vkassert, vk.vkCreateCommandPool, device.obj.id, info, nil)

	self.device = device.obj.id
	self.graphicsQueue = common.graphicsQueue
end

function VulkanCommandPool:transitionImageLayout(image, oldLayout, newLayout, mipLevels)
	VKSingleTimeCommand(self.device, self.graphicsQueue.id, self.id,
	function(commandBuffer)
		local barrier = ffi.new(VkImageMemoryBarrier_1)
		barrier[0].oldLayout = oldLayout
		barrier[0].newLayout = newLayout
		barrier[0].srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED
		barrier[0].dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED
		barrier[0].image = image
		barrier[0].subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT
		barrier[0].subresourceRange.levelCount = mipLevels
		barrier[0].subresourceRange.layerCount = 1

		local srcStage, dstStage
		if oldLayout == vk.VK_IMAGE_LAYOUT_UNDEFINED
		and newLayout == vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
		then
			barrier[0].srcAccessMask = 0
			barrier[0].dstAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT
			srcStage = vk.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT
			dstStage = vk.VK_PIPELINE_STAGE_TRANSFER_BIT
		elseif oldLayout == vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
		and newLayout == vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
		then
			barrier[0].srcAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT
			barrier[0].dstAccessMask = vk.VK_ACCESS_SHADER_READ_BIT
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
            barrier         -- pImageMemoryBarriers
		)
	end)
end

function VulkanCommandPool:copyBuffer(srcBuffer, dstBuffer, size)
	VKSingleTimeCommand(self.device, self.graphicsQueue.id, self.id,
	function(commandBuffer)
		local regions = ffi.new(VkBufferCopy_1)
		regions[0].size = size
		vk.vkCmdCopyBuffer(
			commandBuffer,
			srcBuffer.id,
			dstBuffer.id,
			1,
			regions
		)
	end)
end

function VulkanCommandPool:copyBufferToImage(buffer, image, width, height)
	VKSingleTimeCommand(self.device, self.graphicsQueue.id, self.id,
	function(commandBuffer)
		local regions = ffi.new(VkBufferImageCopy_1)
		regions[0].imageSubresource.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT
		regions[0].imageSubresource.layerCount = 1
		regions[0].imageExtent.width = width
		regions[0].imageExtent.height = height
		regions[0].imageExtent.depth = 1
		vk.vkCmdCopyBufferToImage(
			commandBuffer,
			buffer.id,
			image,
			vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
			1,
			regions
		)
	end)
end


local VulkanDeviceMemoryBuffer = class()

function VulkanDeviceMemoryBuffer:init(physDev, device, size, usage, properties)
	local buffer = VkBuffer{
		device = device,
		size = size,
		usage = usage,
		sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
	}

	local memReq = vkGet(VkMemoryRequirements, nil, vk.vkGetBufferMemoryRequirements, device, buffer.id)

	local info = ffi.new(VkMemoryAllocateInfo_1)
	info[0].allocationSize = memReq.size
	info[0].memoryTypeIndex = physDev:findMemoryType(memReq.memoryTypeBits, properties)
	local memory = vkGet(VkDeviceMemory, vkassert, vk.vkAllocateMemory, device, info, nil)

	vkassert(vk.vkBindBufferMemory, device, buffer.id, memory, 0)

	self.buffer = buffer
	self.memory = memory
end

function VulkanDeviceMemoryBuffer:makeBufferFromStaged(physDev, device, commandPool, srcData, bufferSize)
	-- TODO esp this, is a raii ,and should free upon dtor upon scope end
	local stagingBufferAndMemory = VulkanDeviceMemoryFromStagingBuffer:create(
		physDev,
		device,
		srcData,
		bufferSize
	)

	local bufferAndMemory = VulkanDeviceMemoryBuffer(
		physDev,
		device,
		bufferSize,
		bit.bor(vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
			vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT),
		vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
	)

	commandPool:copyBuffer(
		stagingBufferAndMemory.buffer,
		bufferAndMemory.buffer,
		bufferSize
	)

	stagingBufferAndMemory.buffer:destroy()

	return bufferAndMemory
end


local VulkanBufferMemoryAndMapped = class()

function VulkanBufferMemoryAndMapped:init(bm, mapped)
	self.bm = bm
	self.mapped = mapped
end


local VulkanMesh = class()

function VulkanMesh:init(physDev, device, commandPool)
	local ObjLoader = require 'mesh.objloader'
	local mesh = ObjLoader():load"viking_room.obj";

	local indices = mesh.triIndexes	-- vector'int32_t'
	asserteq(indices.type, ffi.typeof'int32_t') 	-- well, uint, but whatever
	-- copy from MeshVertex_t to Vertex ... TODO why bother ...
	local vertices = vector'Vertex'
	vertices:resize(#mesh.vtxs)
	for i=0,#mesh.vtxs-1 do
		local srcv = mesh.vtxs.v[i]
		local dstv = vertices.v[i]
		dstv.pos = srcv.pos
		dstv.texCoord = srcv.texcoord	-- TODO y-flip?
		dstv.color:set(1, 1, 1)	-- do our objects have normal properties?  nope, just v vt vn ... why doesn't the demo use normals? does it bake lighting?
	end

	self.vertexBufferAndMemory = VulkanDeviceMemoryBuffer:makeBufferFromStaged(
		physDev,
		device.obj.id,
		commandPool,
		vertices.v,
		#vertices * ffi.sizeof(vertices.type)
	)

	self.numIndices = #indices
	self.indexBufferAndMemory = VulkanDeviceMemoryBuffer:makeBufferFromStaged(
		physDev,
		device.obj.id,
		commandPool,
		indices.v,
		#indices * ffi.sizeof(indices.type)
	)
end


local VulkanCommon = class()

VulkanCommon.enableValidationLayers = false
VulkanCommon.maxFramesInFlight = 2

function VulkanCommon:init(app)
	self.app = assert(app)
	self.framebufferResized = false
	self.currentFrame = 0

	assert(not self.enableValidationLayers or self:checkValidationLayerSupport(), "validation layers requested, but not available!")
	self.instance = VulkanInstance(self)

	self.surface = VkSurface{
		window = app.window,
		instance = self.instance.obj,
	}

	local deviceExtensions = vector'char const *'
	deviceExtensions:emplace_back()[0] = vk.VK_KHR_SWAPCHAIN_EXTENSION_NAME

	self.physDev = VulkanPhysicalDevice(self, deviceExtensions)

	self.msaaSamples = self.physDev:getMaxUsableSampleCount()
print('msaaSamples', self.msaaSamples)

	do
		local indices = self.physDev:findQueueFamilies(nil, self.surface)
		self.device = VulkanDevice(
			self.physDev.obj,
			deviceExtensions,
			self.enableValidationLayers,
			indices
		)
		self.graphicsQueue = VkQueue{device=self.device.obj, family=indices.graphicsFamily}
		self.presentQueue = VkQueue{device=self.device.obj, family=indices.presentFamily}
	end

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

	local info = ffi.new(VkSamplerCreateInfo_1)
	info[0].magFilter = vk.VK_FILTER_LINEAR
	info[0].minFilter = vk.VK_FILTER_LINEAR
	info[0].mipmapMode = vk.VK_SAMPLER_MIPMAP_MODE_LINEAR
	info[0].addressModeU = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT
	info[0].addressModeV = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT
	info[0].addressModeW = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT
	info[0].anisotropyEnable = vk.VK_TRUE
	info[0].maxAnisotropy = self.physDev.obj:getProps().limits.maxSamplerAnisotropy
	info[0].compareEnable = vk.VK_FALSE
	info[0].compareOp = vk.VK_COMPARE_OP_ALWAYS
	info[0].minLod = 0
	info[0].maxLod = self.mipLevels
	info[0].borderColor = vk.VK_BORDER_COLOR_INT_OPAQUE_BLACK
	info[0].unnormalizedCoordinates = vk.VK_FALSE
	self.textureSampler = vkGet(VkSampler, vkassert, vk.vkCreateSampler, self.device.obj.id, info, nil)

	self.mesh = VulkanMesh(self.physDev, self.device, self.commandPool)
	self.uniformBuffers = range(self.maxFramesInFlight):mapi(function(i)
		local size = ffi.sizeof'UniformBufferObject'
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
		local mapped = vkGet('void*', vkassert, vk.vkMapMemory, self.device.obj.id, bm.memory, 0, size, 0)
		return VulkanBufferMemoryAndMapped(bm, mapped)
	end)

	local poolSizes = vector(VkDescriptorPoolSize)
	local p = poolSizes:emplace_back()
	p[0].type = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
	p[0].descriptorCount = self.maxFramesInFlight
	local p = poolSizes:emplace_back()
	p[0].type = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
	p[0].descriptorCount = self.maxFramesInFlight

	local info = ffi.new(VkDescriptorPoolCreateInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO
	info[0].maxSets = self.maxFramesInFlight
	info[0].poolSizeCount = #poolSizes
	info[0].pPoolSizes = poolSizes.v
	self.descriptorPool = vkGet(VkDescriptorPool, vkassert, vk.vkCreateDescriptorPool, self.device.obj.id, info, nil)

	self.descriptorSets = self:createDescriptorSets()

	local info = ffi.new(VkCommandBufferAllocateInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
	info[0].commandPool = self.commandPool.id
	info[0].level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY
	info[0].commandBufferCount = self.maxFramesInFlight
	--[[
	self.commandBuffers = vkGet(VkCommandBuffer, vkassert, vk.vkAllocateCommandBuffers, self.device.obj.id, info)
	--]]
	-- [[ can't use vkGet and can't use vkGetVector ...
	self.commandBuffers = vector(VkCommandBuffer)
	self.commandBuffers:resize(self.maxFramesInFlight)
	vkassert(vk.vkAllocateCommandBuffers, self.device.obj.id, info, self.commandBuffers.v)
	--]]

	self.imageAvailableSemaphores = vector(VkSemaphore)
	for i=0,self.maxFramesInFlight-1 do
		local info = ffi.new(VkSemaphoreCreateInfo_1)
		info[0].sType = vk.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
		self.imageAvailableSemaphores:push_back(vkGet(VkSemaphore, vkassert, vk.vkCreateSemaphore, self.device.obj.id, info, nil))
	end

	self.renderFinishedSemaphores = vector(VkSemaphore)
	for i=0,self.maxFramesInFlight-1 do
		local info = ffi.new(VkSemaphoreCreateInfo_1)
		info[0].sType = vk.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
		self.renderFinishedSemaphores:push_back(vkGet(VkSemaphore, vkassert, vk.vkCreateSemaphore, self.device.obj.id, info, nil))
	end

	self.inFlightFences = vector(VkFence)
	for i=0,self.maxFramesInFlight-1 do
		local info = ffi.new(VkFenceCreateInfo_1)
		info[0].sType = vk.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO
		info[0].flags = vk.VK_FENCE_CREATE_SIGNALED_BIT
		self.inFlightFences:push_back(vkGet(VkFence, vkassert, vk.vkCreateFence, self.device.obj.id, info, nil))
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

	VKSingleTimeCommand(self.device.obj.id, self.graphicsQueue.id, self.commandPool.id,
	function(commandBuffer)
		local barrier = ffi.new(VkImageMemoryBarrier_1)
		barrier[0].srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED
		barrier[0].dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED
		barrier[0].image = image
		barrier[0].subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT
		barrier[0].subresourceRange.levelCount = 1
		barrier[0].subresourceRange.layerCount = 1

		local mipWidth = texWidth
		local mipHeight = texHeight

		for i=1,mipLevels-1 do
			barrier[0].subresourceRange.baseMipLevel = i - 1
			barrier[0].oldLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
			barrier[0].newLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL
			barrier[0].srcAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT
			barrier[0].dstAccessMask = vk.VK_ACCESS_TRANSFER_READ_BIT

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
				barrier								-- pImageMemoryBarriers
			)

			local blit = ffi.new(VkImageBlit_1)
			blit[0].srcSubresource.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT
			blit[0].srcSubresource.mipLevel = i-1
			blit[0].srcSubresource.layerCount = 1
			blit[0].srcOffsets[1].x = mipWidth
			blit[0].srcOffsets[1].y = mipHeight
			blit[0].srcOffsets[1].z = 1
			blit[0].dstSubresource.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT
			blit[0].dstSubresource.mipLevel = i
			blit[0].dstSubresource.layerCount = 1
			blit[0].dstOffsets[1].x = mipWidth > 1 and math.floor(mipWidth / 2) or 1
			blit[0].dstOffsets[1].y = mipHeight > 1 and math.floor(mipHeight / 2) or 1
			blit[0].dstOffsets[1].z = 1

			vk.vkCmdBlitImage(
				commandBuffer,
				image,
				vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
				image,
				vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
				1,
				blit,
				vk.VK_FILTER_LINEAR
			)

			barrier[0].oldLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL
			barrier[0].newLayout = vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
			barrier[0].srcAccessMask = vk.VK_ACCESS_TRANSFER_READ_BIT
			barrier[0].dstAccessMask = vk.VK_ACCESS_SHADER_READ_BIT

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
				barrier										-- pImageMemoryBarriers
			)

			if mipWidth > 1 then mipWidth = math.floor(mipWidth / 2) end
			if mipHeight > 1 then mipHeight = math.floor(mipHeight / 2) end
		end

		barrier[0].subresourceRange.baseMipLevel = mipLevels - 1;
		barrier[0].oldLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
		barrier[0].newLayout = vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL
		barrier[0].srcAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT
		barrier[0].dstAccessMask = vk.VK_ACCESS_TRANSFER_READ_BIT

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
			barrier										-- pImageMemoryBarriers
		)
	end)
end

function VulkanCommon:createDescriptorSets()
	local layouts = vector(VkDescriptorSetLayout)
	for i=0,self.maxFramesInFlight-1 do
		layouts:push_back(self.graphicsPipeline.descriptorSetLayout)
	end

	local info = ffi.new(VkDescriptorSetAllocateInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO
	info[0].descriptorPool = self.descriptorPool
	info[0].descriptorSetCount = #layouts -- self.maxFramesInFlight
	info[0].pSetLayouts = layouts.v	-- length matches descriptorSetCount I think?

	--[[ vkGet just allocates one
	-- vkGetVector expects a 'count' field to determine size
	-- ... we have to statically allocate for this function ...
	local descriptorSets = vkGet(VkDescriptorSet,
		vkassert,
		vk.vkAllocateDescriptorSets,
		self.device.obj.id,
		info
	)
	--]]
	-- [[
	local descriptorSets = vector(VkDescriptorSet)
	descriptorSets:resize(self.maxFramesInFlight)
	vkassert(vk.vkAllocateDescriptorSets, self.device.obj.id, info, descriptorSets.v)
	--]]

	for i=0,self.maxFramesInFlight-1 do
		local bufferInfo = ffi.new(VkDescriptorBufferInfo_1)
		bufferInfo[0].buffer = self.uniformBuffers[i+1].buffer
		bufferInfo[0].range = ffi.sizeof'UniformBufferObject'

		local imageInfo = ffi.new(VkDescriptorImageInfo_1)
		imageInfo[0].sampler = self.textureSampler
		imageInfo[0].imageView = self.textureImageView
		imageInfo[0].imageLayout = vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL

		local descriptorWrites = vector(VkWriteDescriptorSet)
		local d = descriptorWrites:emplace_back()
		d[0].sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
		d[0].dstSet = descriptorSets.v[i]
		d[0].dstBinding = 0
		d[0].descriptorCount = 1
		d[0].descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
		d[0].pBufferInfo = bufferInfo

		local d = descriptorWrites:emplace_back()
		d[0].sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
		d[0].dstSet = descriptorSets.v[i]
		d[0].dstBinding = 1
		d[0].descriptorCount = 1
		d[0].descriptorType = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
		d[0].pImageInfo = imageInfo

		vk.vkUpdateDescriptorSets(
			self.device.obj.id,
			#descriptorWrites,
			descriptorWrites.v,
			0,
			nil)
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
	local info = ffi.new(VkAcquireNextImageInfoKHR_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_ACQUIRE_NEXT_IMAGE_INFO_KHR
	info[0].pNext = nil
	info[0].swapchain = self.swapchain.obj.id
	info[0].timeout = ffi.cast(uint64_t, -1)
	info[0].semaphore = self.imageAvailableSemaphores.v[self.currentFrame]
	info[0].fence = nil
	info[0].deviceMask = 0
	local result = vk.vkAcquireNextImage2KHR(assert(self.device.obj.id), info, imageIndex)
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

	local waitStages = ffi.new(VkPipelineStageFlags_1)
	waitStages[0] = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT

	local info = ffi.new(VkSubmitInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO
	info[0].waitSemaphoreCount = 1
	info[0].pWaitSemaphores = self.imageAvailableSemaphores.v + self.currentFrame
	info[0].pWaitDstStageMask = waitStages
	info[0].commandBufferCount = 1
	info[0].pCommandBuffers = self.commandBuffers.v + self.currentFrame
	info[0].signalSemaphoreCount = 1
	info[0].pSignalSemaphores = self.renderFinishedSemaphores.v + self.currentFrame
	vkassert(vk.vkQueueSubmit,
		self.graphicsQueue.id,
		1,
		info,
		self.inFlightFences.v[self.currentFrame]
	)

	-- TODO reason to keep the gc'd ptr around
	local swapchains = ffi.new(VkSwapchainKHR_1)
	swapchains[0] = self.swapchain.obj.id

	local info = ffi.new(VkPresentInfoKHR_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR
	info[0].waitSemaphoreCount = 1
	info[0].pWaitSemaphores = self.renderFinishedSemaphores.v + self.currentFrame
	info[0].swapchainCount = 1
	info[0].pSwapchains = swapchains
	info[0].pImageIndices = imageIndex
	-- TODO what's info[0].pResults vs the results returned from vkQueuePresentKHR ?
	local result = vk.vkQueuePresentKHR(
		self.presentQueue.id,
		info)
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
}, 'float')

VulkanCommon.startTime = timer.getTime()
function VulkanCommon:updateUniformBuffer()
	local app = self.app
	local currentTime = timer.getTime()
	local time = currentTime - self.startTime

-- don't need this unless I start doing the matrix calculations here
--	local ar = tonumber(self.swapchain.extent.width) / tonumber(self.swapchain.extent.height)

	local ubo = UniformBufferObject()
-- [[ TODO maybe transpose ...
	ffi.copy(ubo.model, app.view.mvMat.ptr, 4 * 4 * ffi.sizeof'float')
	ffi.copy(ubo.view, identMat.ptr, 4 * 4 * ffi.sizeof'float')
	ffi.copy(ubo.proj, app.view.projMat.ptr, 4 * 4 * ffi.sizeof'float')
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
	ffi.copy(self.uniformBuffers[self.currentFrame+1].mapped, ubo, ffi.sizeof'UniformBufferObject')
end

function VulkanCommon:recordCommandBuffer(commandBuffer, imageIndex)
	-- TODO per vulkan api, if we just have null info, can we pass null?
	local info = ffi.new(VkCommandBufferBeginInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
	vkassert(vk.vkBeginCommandBuffer, commandBuffer, info)

	local clearValues = vector(VkClearValue)
	local c = clearValues:emplace_back()
	c[0].color.float32[0] = 0
	c[0].color.float32[1] = 0
	c[0].color.float32[2] = 0
	c[0].color.float32[3] = 1
	local c = clearValues:emplace_back()
	c[0].depthStencil.depth = 1
	c[0].depthStencil.stencil = 0

	local info = ffi.new(VkRenderPassBeginInfo_1)
	info[0].sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO
	info[0].renderPass = self.swapchain.renderPass
	info[0].framebuffer = self.swapchain.framebuffers.v[imageIndex]
	-- TODO will equals assign here, or will it just mess things up?
	info[0].renderArea.extent.width = self.swapchain.extent.width
	info[0].renderArea.extent.height = self.swapchain.extent.height
	info[0].clearValueCount = #clearValues
	info[0].pClearValues = clearValues.v
	vk.vkCmdBeginRenderPass(commandBuffer, info, vk.VK_SUBPASS_CONTENTS_INLINE)

	vk.vkCmdBindPipeline(commandBuffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, self.graphicsPipeline.id)

	local viewports = ffi.new(VkViewport_1)
	viewports[0].width = self.swapchain.extent.width
	viewports[0].height = self.swapchain.extent.height
	viewports[0].minDepth = 0
	viewports[0].maxDepth = 1
	vk.vkCmdSetViewport(commandBuffer, 0, 1, viewports)

	local scissors = ffi.new(VkRect2D_1)
	scissors[0].extent.width = self.swapchain.extent.width
	scissors[0].extent.height = self.swapchain.extent.height
	vk.vkCmdSetScissor(commandBuffer, 0, 1, scissors)

	local vertexBuffers = ffi.new(VkBuffer_1)
	vertexBuffers[0] = assert(self.mesh.vertexBufferAndMemory.buffer.id)
	local vertexOffsets = ffi.new(VkDeviceSize_1)
	asserteq(vertexOffsets[0], 0)
	vk.vkCmdBindVertexBuffers(commandBuffer, 0, 1, vertexBuffers, vertexOffsets)

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

-- [[ VulkanApp
local SDLApp = require 'sdl.app'

-- TODO move view and orbit out of glapp ... but to where ...
-- seems like we're going to need a geometry library soon ...
-- TODO should glapp.view always :subclass() for you? like glapp.orbit and imgui.withorbit already do?
local VulkanApp = require 'glapp.view'.apply(SDLApp):subclass()

VulkanApp.title = 'Vulkan test'
VulkanApp.sdlCreateWindowFlags = bit.bor(
	VulkanApp.sdlCreateWindowFlags,
	--sdl.SDL_WINDOW_HIDDEN, -- added in hopes to fix my sdl init problem...
	sdl.SDL_WINDOW_VULKAN
)

function VulkanApp:initWindow()
	VulkanApp.super.initWindow(self)
	self.vkCommon = VulkanCommon(self)
print('VulkanApp:initWindow done')
end

function VulkanApp:postUpdate()
	self.vkCommon:drawFrame()
	VulkanApp.super.postUpdate(self)
end

function VulkanCommon:resize()
	self.vkCommon:setFramebufferResized()
end

function VulkanApp:exit()
	if self.vkCommon then self.vkCommon:exit() end

	VulkanApp.super.exit(self)
end

return VulkanApp
