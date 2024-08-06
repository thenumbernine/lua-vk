local ffi = require 'ffi'
local range = require 'ext.range'
local table = require 'ext.table'
local vec3f = require 'vec-ffi.vec3f'
local math = require 'ext.math'	-- clamp
local vk = require 'ffi.req' 'vulkan'
local vector = require 'ffi.cpp.vector-lua'
local asserteq = require 'ext.assert'.eq

-- TODO put these in SDL2 ... they don't immediately #include
local sdl = require 'sdl'
ffi.cdef[[
SDL_bool SDL_Vulkan_GetInstanceExtensions(
	SDL_Window *window,
	unsigned int *pCount,
	const char **pNames);

SDL_bool SDL_Vulkan_CreateSurface(
	SDL_Window *window,
	VkInstance instance,
	VkSurfaceKHR* surface);
]]
local function sdlvksafe(f, ...)
	asserteq(sdl.SDL_TRUE, f(...))
end

-- TODO move these to vk:
local VK_EXT_DEBUG_UTILS_EXTENSION_NAME = "VK_EXT_debug_utils"
local VK_KHR_SWAPCHAIN_EXTENSION_NAME = "VK_KHR_swapchain"
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

local function vkassert(f, ...)
	local res = f(...)
	if res ~= vk.VK_SUCCESS then
		error('failed with error '..tostring(res))
	end
end

local function addlast(last, ...)
	if select('#', ...) == 0 then
		return last
	else
		return select(1, ...), addlast(last, select(2, ...))
	end
end

local function vkGet(ctype, check, f, ...)
	local result = ffi.new(ctype..'[1]')
	if check then
		check(f, addlast(result, ...))
	else
		f(addlast(result, ...))
	end
	return result[0]
end

local function vkGetVector(ctype, check, f, ...)
	local count = ffi.new'uint32_t[1]'
	if check then
		check(f, addlast(nil, addlast(count, ...)))
	else
		f(addlast(nil, addlast(count, ...)))
	end
	local vec = vector(ctype)
	vec:resize(count[0])
	if check then
		check(f, addlast(vec.v, addlast(count, ...)))
	else
		f(addlast(vec.v, addlast(count, ...)))
	end
	return vec
end

local VKInstance = class()

function VKInstance:init(app, enableValidationLayers)
	local layerProps = vkGetVector('VkLayerProperties', vkassert, vk.vkEnumerateInstanceLayerProperties)
	print'vulkan layers:'
	for i=0,#layerProps-1 do
		print('',
			ffi.string(layerProps.v[i].layerName, vk.VK_MAX_EXTENSION_NAME_SIZE),
			ffi.string(layerProps.v[i].description, vk.VK_MAX_DESCRIPTION_SIZE)
		)
	end

	local appInfo = ffi.new('VkApplicationInfo[1]')
	appInfo[0].sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO
	appInfo[0].pApplicationName = app.title
	appInfo[0].applicationVersion = VK_MAKE_API_VERSION(0, 1, 0, 0)
	appInfo[0].pEngineName = "No Engine"
	appInfo[0].engineVersion = VK_MAKE_API_VERSION(0, 1, 0, 0)
	appInfo[0].apiVersion = VK_API_VERISON_1_0

	local layerNames = vector'char const *'
	if enableValidationLayers then
		layerNames:emplace_back()[0] = 'VK_LAYER_KHRONOS_validation'
	end

	local extensions = self:getRequiredExtensions(app, enableValidationLayers)

	local info = ffi.new('VkInstanceCreateInfo[1]')
	info[0].sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
	info[0].pApplicationInfo = appInfo
	info[0].enabledLayerCount = #layerNames
	info[0].ppEnabledLayerNames = layerNames.v
	info[0].enabledExtensionCount = #extensions
	info[0].ppEnabledExtensionNames = extensions.v

	-- TODO use this as the gcptr
	self.id = vkGet('VkInstance', vkassert, vk.vkCreateInstance, info, nil);
end

function VKInstance:destroy()
	vk.vkDestroyInstance(self.id, nil)
end

function VKInstance:getRequiredExtensions(app, enableValidationLayers)
	local extensions = vkGetVector('char const *', sdlvksafe, sdl.SDL_Vulkan_GetInstanceExtensions, app.window)

	print'vulkan extensions:'
	for i=0,#extensions-1 do
		print('', ffi.string(extensions.v[i]))
	end

	if enableValidationLayers then
		extensions:emplace_back()[0] = VK_EXT_DEBUG_UTILS_EXTENSION_NAME
	end

	return extensions
end


local VKPhysicalDevice = class()

function VKPhysicalDevice:init(instance, surface, deviceExtensions)
	local physDevs = vkGetVector('VkPhysicalDevice', vkassert, vk.vkEnumeratePhysicalDevices, instance)
	print'devices:'
	for i=0,#physDevs-1 do
		local props = VKPhysicalDevice:getProps(physDevs.v[i])
		print('',
			ffi.string(props.deviceName)
			..' type='..tostring(props.deviceType)
		)
	end

	for i=0,#physDevs-1 do
		if self:isDeviceSuitable(physDevs.v[i], surface, deviceExtensions) then
			self.id = physDevs.v[i]
			return
		end
	end

	error "failed to find a suitable GPU"
end

-- static method
function VKPhysicalDevice:isDeviceSuitable(physDev, surface, deviceExtensions)
	local indices = self:findQueueFamilies(physDev, surface)
	local extensionsSupported = self:checkDeviceExtensionSupport(physDev, deviceExtensions)
	local swapChainAdequate
	if extensionsSupported then
		local swapChainSupport = self:querySwapChainSupport(physDev, surface)
		swapChainAdequate = #swapChainSupport.formats > 0 and #swapChainSupport.presentModes > 0
	end

	local features = vkGet('VkPhysicalDeviceFeatures', nil, vk.vkGetPhysicalDeviceFeatures, physDev)
	return indices
		and extensionsSupported
		and swapChainAdequate
		and features.samplerAnisotropy ~= 0
end

-- static method
function VKPhysicalDevice:findQueueFamilies(physDev, surface)
	physDev = physDev or self.id
	local indices = {}
	local queueFamilies = vkGetVector('VkQueueFamilyProperties', nil, vk.vkGetPhysicalDeviceQueueFamilyProperties, physDev)
	for i=0,#queueFamilies-1 do
		local f = queueFamilies.v[i]
		if 0 ~= bit.band(f.queueFlags, vk.VK_QUEUE_GRAPHICS_BIT) then
			indices.graphicsFamily = i
		end

		local supported = vkGet('VkBool32', vkassert, vk.vkGetPhysicalDeviceSurfaceSupportKHR, physDev, i, surface)
		if supported ~= 0 then
			indices.presentFamily = i
		end
		if indices.graphicsFamily and indices.presentFamily then
			return indices
		end
	end
	error "couldn't find all indices"
end

-- static method
function VKPhysicalDevice:checkDeviceExtensionSupport(physDev, deviceExtensions)
	local requiredExtensions = deviceExtensions:totable():mapi(function(v)
		return true, ffi.string(v)
	end):setmetatable(nil)

	local layerName = nil	-- TODO ???
	local physDevExts = vkGetVector('VkExtensionProperties', vkassert, vk.vkEnumerateDeviceExtensionProperties, physDev, layerName)
	for i=0,#physDevExts-1 do
		requiredExtensions[ffi.string(physDevExts.v[i].extensionName)] = nil
	end
	return next(requiredExtensions) == nil
end

-- static method
function VKPhysicalDevice:querySwapChainSupport(physDev, surface)
	physDev = physDev or self.id
	return {
		capabilities = vkGet('VkSurfaceCapabilitiesKHR', vkassert, vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR, physDev, surface),
		formats = vkGetVector('VkSurfaceFormatKHR', vkassert, vk.vkGetPhysicalDeviceSurfaceFormatsKHR, physDev, surface),
		presentModes = vkGetVector('VkPresentModeKHR', vkassert, vk.vkGetPhysicalDeviceSurfacePresentModesKHR, physDev, surface),
	}
end

function VKPhysicalDevice:getProps(physDev)
	return vkGet('VkPhysicalDeviceProperties', nil, vk.vkGetPhysicalDeviceProperties, physDev or self.id)
end

function VKPhysicalDevice:getFormatProps(physDev, format)
	physDev = physDev or self.id
	return vkGet('VkFormatProperties', nil, vk.vkGetPhysicalDeviceFormatProperties, physDev, format)
end

function VKPhysicalDevice:getMaxUsableSampleCount(...)
	local props = self:getProps(...)
	local counts = bit.band(props.limits.framebufferColorSampleCounts, props.limits.framebufferDepthSampleCounts)
	if 0 ~= bit.band(counts, vk.VK_SAMPLE_COUNT_64_BIT) then return vk.VK_SAMPLE_COUNT_64_BIT end
	if 0 ~= bit.band(counts, vk.VK_SAMPLE_COUNT_32_BIT) then return vk.VK_SAMPLE_COUNT_32_BIT end
	if 0 ~= bit.band(counts, vk.VK_SAMPLE_COUNT_16_BIT) then return vk.VK_SAMPLE_COUNT_16_BIT end
	if 0 ~= bit.band(counts, vk.VK_SAMPLE_COUNT_8_BIT) then return vk.VK_SAMPLE_COUNT_8_BIT end
	if 0 ~= bit.band(counts, vk.VK_SAMPLE_COUNT_4_BIT) then return vk.VK_SAMPLE_COUNT_4_BIT end
	if 0 ~= bit.band(counts, vk.VK_SAMPLE_COUNT_2_BIT) then return vk.VK_SAMPLE_COUNT_2_BIT end
	return vk.VK_SAMPLE_COUNT_1_BIT
end

function VKPhysicalDevice:findDepthFormat()
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

function VKPhysicalDevice:findSupportedFormat(candidates, tiling, features)
	for _,format in ipairs(candidates) do
		local props = self:getFormatProps(nil, format)
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

function VKPhysicalDevice:findMemoryType(mask, props)
	local memProps = vkGet('VkPhysicalDeviceMemoryProperties', nil, vk.vkGetPhysicalDeviceMemoryProperties, self.id)
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

local VKDevice = class()

function VKDevice:init(physDev, deviceExtensions, enableValidationLayers, indices)
	self.id = self:createDevice(physDev, deviceExtensions, enableValidationLayers, indices)
	self.graphicsQueue = vkGet('VkQueue', nil, vk.vkGetDeviceQueue, self.id, indices.graphicsFamily, 0)
	self.presentQueue = vkGet('VkQueue', nil, vk.vkGetDeviceQueue, self.id, indices.presentFamily, 0)
end

function VKDevice:createDevice(physDev, deviceExtensions, enableValidationLayers, indices)
	local queuePriorities = vector'float'
	queuePriorities:emplace_back()[0] = 1
	local queueCreateInfos = vector'VkDeviceQueueCreateInfo'
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

	local deviceFeatures = ffi.new'VkPhysicalDeviceFeatures[1]'
	deviceFeatures[0].samplerAnisotropy = vk.VK_TRUE

	local thisValidationLayers = vector'char const *'
	if enableValidationLayers then
		thisValidationLayers.emplace_back()[0] = validationLayer	-- TODO vector copy?
	end

	local info = ffi.new'VkDeviceCreateInfo[1]'
	info[0].sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
	info[0].queueCreateInfoCount = #queueCreateInfos
	info[0].pQueueCreateInfos = queueCreateInfos.v
	info[0].enabledLayerCount = #thisValidationLayers
	info[0].ppEnabledLayerNames = thisValidationLayers.v
	info[0].enabledExtensionCount = #deviceExtensions
	info[0].ppEnabledExtensionNames = deviceExtensions.v
	info[0].pEnabledFeatures = deviceFeatures
	return vkGet('VkDevice', vkassert, vk.vkCreateDevice, physDev, info, nil)
end


local VKDeviceMakeFromStagingBuffer = class()

function VKDeviceMakeFromStagingBuffer:create(physDev, device, srcData, bufferSize)
	local info = ffi.new'VkBufferCreateInfo[1]'
	info[0].sType = vk.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO
	info[0].size = bufferSize
	info[0].usage = vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT
	info[0].sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE
	local buffer = vkGet('VkBuffer', vkassert, vk.vkCreateBuffer, device, info, nil)

	local memReq = vkGet('VkMemoryRequirements', nil, vk.vkGetBufferMemoryRequirements, device, buffer)

	local info = ffi.new'VkMemoryAllocateInfo[1]'
	info[0].allocationSize = memReq.size
	info[0].memoryTypeIndex = physDev:findMemoryType(memReq.memoryTypeBits, bit.bor(vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT, vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT))
	local memory = vkGet('VkDeviceMemory', vkassert, vk.vkAllocateMemory, device, info, nil)

	vkassert(vk.vkBindBufferMemory, device, buffer, memory, 0)

	local dstData = vkGet('void*', vkassert, vk.vkMapMemory, device, memory, 0, bufferSize, 0)
	ffi.copy(dstData, srcData, bufferSize)

	vk.vkUnmapMemory(device, memory)

	return {buffer=buffer, memory=memory}
end


local VKDeviceMemoryImage = class()

function VKDeviceMemoryImage:createImage(
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
	local info = ffi.new'VkImageCreateInfo[1]'
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
	local image = vkGet('VkImage', vkassert, vk.vkCreateImage, device, info, nil)

	local memReq = vkGet('VkMemoryRequirements', nil, vk.vkGetImageMemoryRequirements, device, image)

	local info = ffi.new'VkMemoryAllocateInfo[1]'
	info[0].sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO
	info[0].allocationSize = memReq.size
	info[0].memoryTypeIndex = physDev:findMemoryType(memReq.memoryTypeBits, properties)
	local imageMemory = vkGet('VkDeviceMemory', vkassert, vk.vkAllocateMemory, device, info, nil)
	vkassert(vk.vkBindImageMemory, device, image, imageMemory, 0)

	return {image=image, imageMemory=imageMemory}
end

function VKDeviceMemoryImage:makeTextureFromStaged(
	physDev,
	device,
	commandPool,
	srcData,
	bufferSize,
	texWidth,
	texHeight,
	mipLevels
)
	local stagingBufferAndMemory = VKDeviceMakeFromStagingBuffer:create(physDev, device, srcData, bufferSize)
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

	return imageAndMemory
end

local VKSwapchain = class()

function VKSwapchain:init(width, height, physDev, device, surface, msaaSamples)
	local swapChainSupport = physDev:querySwapChainSupport(nil, surface)
	local extent = self:chooseSwapExtent(width, height, swapChainSupport.capabilities)

	local imageCount = swapChainSupport.capabilities.minImageCount + 1
	if swapChainSupport.capabilities.maxImageCount > 0 then
		imageCount = math.min(imageCount, swapChainSupport.capabilities.maxImageCount)
	end

	local surfaceFormat = self:chooseSwapSurfaceFormat(swapChainSupport.formats)
	local presentMode = self:chooseSwapPresentMode(swapChainSupport.presentModes)
	local info = ffi.new'VkSwapchainCreateInfoKHR[1]'
	info[0].sType = vk.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR
	info[0].surface = surface
	info[0].minImageCount = imageCount
	info[0].imageFormat = surfaceFormat.format
	info[0].imageColorSpace = surfaceFormat.colorSpace
	info[0].imageExtent = extent
	info[0].imageArrayLayers = 1
	info[0].imageUsage = vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT
	info[0].preTransform = swapChainSupport.capabilities.currentTransform
	info[0].compositeAlpha = vk.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR
	info[0].presentMode = presentMode
	info[0].clipped = vk.VK_TRUE
	local indices = physDev:findQueueFamilies(nil, surface)
	local queueFamilyIndices = vector'uint32_t'
	for index in pairs{
		[indices.graphicsFamily] = true,
		[indices.presentFamily] = true,
	} do
		queueFamilyIndices:emplace_back()[0] = index
	end
	if indices.graphicsFamily ~= indices.presentFamily then
		info[0].imageSharingMode = vk.VK_SHARING_MODE_CONCURRENT
		info[0].queueFamilyIndexCount = #queueFamilyIndices
		info[0].pQueueFamilyIndices = queueFamilyIndices.v
	else
		info[0].imageSharingMode = vk.VK_SHARING_MODE_EXCLUSIVE
	end

	local id = vkGet('VkSwapchainKHR', vkassert, vk.vkCreateSwapchainKHR, device, info, nil)

	local images = vkGetVector('VkImage', vkassert, vk.vkGetSwapchainImagesKHR, device, id)

	local imageViews = vector'VkImageView'
	for i=0,#images-1 do
		imageViews:emplace_back()[0] = self:createImageView(
			device,
			images.v[i],
			surfaceFormat.format,
			vk.VK_IMAGE_ASPECT_COLOR_BIT,
			1)
	end

	local renderPass = self:createRenderPass(physDev, device, surfaceFormat.format, msaaSamples)

	local colorFormat = surfaceFormat.format

	local colorImageAndMemory = VKDeviceMemoryImage:createImage(
		physDev,
		device,
		width,
		height,
		1,
		msaaSamples,
		colorFormat,
		vk.VK_IMAGE_TILING_OPTIMAL,
		bit.bor(vk.VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT, vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT),
		vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
	)

	local colorImageView = self:createImageView(
		device,
		colorImageAndMemory.image,
		colorFormat,
		vk.VK_IMAGE_ASPECT_COLOR_BIT,
		1
	)

	local depthFormat = physDev:findDepthFormat()

	local depthImageAndMemory = VKDeviceMemoryImage:createImage(
		physDev,
		device,
		width,
		height,
		1,
		msaaSamples,
		depthFormat,
		vk.VK_IMAGE_TILING_OPTIMAL,
		vk.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
		vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
	)
	local depthImageView = self:createImageView(
		device,
		depthImageAndMemory.image,
		depthFormat,
		vk.VK_IMAGE_ASPECT_DEPTH_BIT,
		1
	)

	local framebuffers = vector'VkFramebuffer'
	for i=0,#imageViews-1 do
		local attachments = vector'VkImageView'
		attachments:push_back(colorImageView)
		attachments:push_back(depthImageView)
		attachments:push_back(imageViews.v[i])
		local info = ffi.new'VkFramebufferCreateInfo[1]'
		info[0].sType = vk.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO
		info[0].renderPass = renderPass
		info[0].attachmentCount = #attachments
		info[0].pAttachments = attachments.v
		info[0].width = width
		info[0].height = height
		info[0].layers = 1
		framebuffers:push_back(vkGet('VkFramebuffer', vkassert, vk.vkCreateFramebuffer, device, info, nil))
	end

	self.id = id
	self.renderPass = renderPass
	self.depthImageAndMemory = depthImageAndMemory
	self.depthImageView = depthImageView
	self.colorImageAndMemory = colorImageAndMemory
	self.colorImageView = colorImageView
	self.width = width
	self.height = height
	self.images = images
	self.imageViews = imageViews
	self.framebuffers = framebuffers
end

function VKSwapchain:chooseSwapExtent(width, height, capabilities)
	if capabilities.currentExtent.width ~= -1 then
		return capabilities.currentExtent
	else
		local actualExtent = ffi.new('VkExtent2D', width, height)
		actualExtent.width = math.clamp(actualExtent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width)
		actualExtent.height = math.clamp(actualExtent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height)
		return actualExtent
	end
end

function VKSwapchain:chooseSwapSurfaceFormat(availableFormats)
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

function VKSwapchain:chooseSwapPresentMode(availablePresentModes)
	-- return-if-found ... why not just treat this as a set?
	for i=0,#availablePresentModes-1 do
		local presentMode = availablePresentModes.v[i]
		if presentMode == vk.VK_PRESENT_MODE_MAILBOX_KHR then
			return presentMode
		end
	end
	return vk.VK_PRESENT_MODE_FIFO_KHR
end

function VKSwapchain:createImageView(device, image, format, aspectFlags, mipLevels)
	local info = ffi.new'VkImageViewCreateInfo[1]'
	info[0].sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
	info[0].image = image
	info[0].viewType = vk.VK_IMAGE_VIEW_TYPE_2D
	info[0].format = format
	info[0].subresourceRange.aspectMask = aspectFlags
	info[0].subresourceRange.levelCount = mipLevels
	info[0].subresourceRange.layerCount = 1
	return vkGet('VkImageView', vkassert, vk.vkCreateImageView, device, info, nil)
end

function VKSwapchain:createRenderPass(physDev, device, swapChainImageFormat, msaaSamples)
	local attachments = vector'VkAttachmentDescription'
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

	local colorAttachmentRef = ffi.new'VkAttachmentReference[1]'
	colorAttachmentRef[0].attachment = 0
	colorAttachmentRef[0].layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
	local depthAttachmentRef = ffi.new'VkAttachmentReference[1]'
	depthAttachmentRef[0].attachment = 1
	depthAttachmentRef[0].layout = vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL
	local colorAttachmentResolveRef = ffi.new'VkAttachmentReference[1]'
	colorAttachmentResolveRef[0].attachment = 2
	colorAttachmentResolveRef[0].layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL

	local subpasses = vector'VkSubpassDescription'
	local s = subpasses:emplace_back()
	s[0].pipelineBindPoint = vk.VK_PIPELINE_BIND_POINT_GRAPHICS
	s[0].colorAttachmentCount = 1
	s[0].pColorAttachments = colorAttachmentRef
	s[0].pResolveAttachments = colorAttachmentResolveRef
	s[0].pDepthStencilAttachment = depthAttachmentRef

	local dependencies = vector'VkSubpassDependency'
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

	local info = ffi.new'VkRenderPassCreateInfo[1]'
	info[0].sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO
	info[0].attachmentCount = #attachments
	info[0].pAttachments = attachments.v
	info[0].subpassCount = #subpasses
	info[0].pSubpasses = subpasses.v
	info[0].dependencyCount = #dependencies
	info[0].pDependencies = dependencies.v
	return vkGet('VkRenderPass', vkassert, vk.vkCreateRenderPass, device, info, nil)
end


local VKShaderModule = class()

-- TODO lua.make here
-- glslangValidator -V shader.vert -o shader-vert.spv
-- glslangValidator -V shader.frag -o shader-frag.spv
function VKShaderModule:fromFile(device, filename)
	local path = require 'ext.path'
	local code = assert(path(filename):read())
	local info = ffi.new'VkShaderModuleCreateInfo[1]'
	info[0].sType = vk.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO
	info[0].codeSize = #code
	info[0].pCode = ffi.cast('uint32_t*', ffi.cast('char const *', code))
	return vkGet('VkShaderModule', vkassert, vk.vkCreateShaderModule, device, info, nil)
end

local struct = require 'struct'
local Vertex = struct{
	name = 'Vertex',
	fields = {
		{name = 'pos', type = 'vec3f_t'},
		{name = 'color', type = 'vec3f_t'},
		{name = 'texCoord', type = 'vec3f_t'},
	},
	metatable = function(mt)
		mt.getBindingDescription = function()
			local d = ffi.new'VkVertexInputBindingDescription'
			d.binding = 0
			d.stride = ffi.sizeof'Vertex'
			d.inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX
			return d
		end

		mt.getAttributeDescriptions = function()
			local ar = vector'VkVertexInputAttributeDescription'

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

local VKGraphicsPipeline = class()

function VKGraphicsPipeline:init(physDev, device, renderPass, msaaSamples)
	-- descriptorSetLayout is only used by graphicsPipeline
	local bindings = vector'VkDescriptorSetLayoutBinding'

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

	local info = ffi.new'VkDescriptorSetLayoutCreateInfo[1]'
	info[0].sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO
	info[0].bindingCount = #bindings
	info[0].pBindings = bindings.v
	self.descriptorSetLayout = vkGet('VkDescriptorSetLayout', nil, vk.vkCreateDescriptorSetLayout, device, info, nil)

	local vertShaderModule = VKShaderModule:fromFile(device, "shader-vert.spv")
	local fragShaderModule = VKShaderModule:fromFile(device, "shader-frag.spv")

	local bindingDescriptions = vector'VkVertexInputBindingDescription'
	bindingDescriptions:push_back(Vertex:getBindingDescription())

	local attributeDescriptions = Vertex:getAttributeDescriptions();
	local vertexInputInfo = ffi.new'VkPipelineVertexInputStateCreateInfo[1]'
	vertexInputInfo[0].sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
	vertexInputInfo[0].vertexBindingDescriptionCount = #bindingDescriptions
	vertexInputInfo[0].pVertexBindingDescriptions = bindingDescriptions.v
	vertexInputInfo[0].vertexAttributeDescriptionCount = #attributeDescriptions
	vertexInputInfo[0].pVertexAttributeDescriptions = attributeDescriptions.v

	local inputAssembly = ffi.new'VkPipelineInputAssemblyStateCreateInfo[1]'
	inputAssembly[0].topology = vk.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
	inputAssembly[0].primitiveRestartEnable = vk.VK_FALSE

	local viewportState = ffi.new'VkPipelineViewportStateCreateInfo[1]'
	viewportState[0].viewportCount = 1
	viewportState[0].scissorCount = 1

	local rasterizer = ffi.new'VkPipelineRasterizationStateCreateInfo[1]'
	rasterizer[0].depthClampEnable = vk.VK_FALSE
	rasterizer[0].rasterizerDiscardEnable = vk.VK_FALSE
	rasterizer[0].polygonMode = vk.VK_POLYGON_MODE_FILL
	--rasterizer[0].cullMode = vk::CullModeFlagBits::eBack,
	--rasterizer[0].frontFace = vk::FrontFace::eClockwise,
	--rasterizer[0].frontFace = vk::FrontFace::eCounterClockwise,
	rasterizer[0].depthBiasEnable = vk.VK_FALSE
	rasterizer[0].lineWidth = 1

	local multisampling = ffi.new'VkPipelineMultisampleStateCreateInfo[1]'
	multisampling[0].rasterizationSamples = msaaSamples
	multisampling[0].sampleShadingEnable = vk.VK_FALSE

	local depthStencil = ffi.new'VkPipelineDepthStencilStateCreateInfo[1]'
	depthStencil[0].depthTestEnable = vk.VK_TRUE
	depthStencil[0].depthWriteEnable = vk.VK_TRUE
	depthStencil[0].depthCompareOp = vk.VK_COMPARE_OP_LESS
	depthStencil[0].depthBoundsTestEnable = vk.VK_FALSE
	depthStencil[0].stencilTestEnable = vk.VK_FALSE

	local colorBlendAttachment = ffi.new'VkPipelineColorBlendAttachmentState[1]'
	colorBlendAttachment[0].blendEnable = vk.VK_FALSE
	colorBlendAttachment[0].colorWriteMask = bit.bor(
		vk.VK_COLOR_COMPONENT_R_BIT,
		vk.VK_COLOR_COMPONENT_G_BIT,
		vk.VK_COLOR_COMPONENT_B_BIT,
		vk.VK_COLOR_COMPONENT_A_BIT
	)

	local colorBlending = ffi.new'VkPipelineColorBlendStateCreateInfo[1]'
	colorBlending[0].logicOpEnable = vk.VK_FALSE
	colorBlending[0].logicOp = vk.VK_LOGIC_OP_COPY
	colorBlending[0].attachmentCount = 1
	colorBlending[0].pAttachments = colorBlendAttachment
	colorBlending[0].blendConstants[0] = 0
	colorBlending[0].blendConstants[1] = 0
	colorBlending[0].blendConstants[2] = 0
	colorBlending[0].blendConstants[3] = 0

	local dynamicStates = vector'VkDynamicState'
	dynamicStates:push_back(vk.VK_DYNAMIC_STATE_VIEWPORT)
	dynamicStates:push_back(vk.VK_DYNAMIC_STATE_SCISSOR)

	local dynamicState = ffi.new'VkPipelineDynamicStateCreateInfo[1]'
	dynamicState[0].dynamicStateCount = #dynamicStates
	dynamicState[0].pDynamicStates = dynamicStates.v

	local descriptorSetLayouts = vector'VkDescriptorSetLayout'
	descriptorSetLayouts:push_back(self.descriptorSetLayout)

	local info = ffi.new'VkPipelineLayoutCreateInfo[1]'
	info[0].sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
	info[0].setLayoutCount = #descriptorSetLayouts
	info[0].pSetLayouts = descriptorSetLayouts.v
	local pipelineLayout = vkGet('VkPipelineLayout', vkassert, vk.vkCreatePipelineLayout, device, info, nil)

	local shaderStages = vector'VkPipelineShaderStageCreateInfo'

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

	local info = ffi.new'VkGraphicsPipelineCreateInfo[1]'
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
	self.id = vkGet('VkPipeline', vkassert, vk.vkCreateGraphicsPipelines, device, nil, 1, info, nil)
end


function VKSingleTimeCommand(device, queue, commandPool, callback)
	local info = ffi.new'VkCommandBufferAllocateInfo[1]'
	info[0].sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
	info[0].commandPool = commandPool
	info[0].level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY
	info[0].commandBufferCount = 1

	--local cmds = vkGet('VkCommandBuffer', vkassert, vk.vkAllocateCommandBuffers, device, info)
	-- I want to keep the pointer so ...
	local cmds = ffi.new'VkCommandBuffer[1]'
	vkassert(vk.vkAllocateCommandBuffers, device, info, cmds)

	local info = ffi.new'VkCommandBufferBeginInfo[1]'
	info[0].sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
	info[0].flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT
	vkassert(vk.vkBeginCommandBuffer, cmds[0], info)

	callback(cmds[0])

	vkassert(vk.vkEndCommandBuffer, cmds[0])

	local submits = ffi.new'VkSubmitInfo[1]'
	submits[0].sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO
	submits[0].commandBufferCount = 1
	submits[0].pCommandBuffers = cmds
	vkassert(vk.vkQueueSubmit, queue, 1, submits, nil)
	vkassert(vk.vkQueueWaitIdle, queue)
end


local VKCommandPool = class()

function VKCommandPool:init(physDev, device, surface)
	local queueFamilyIndices = physDev:findQueueFamilies(nil, surface)

	local info = ffi.new'VkCommandPoolCreateInfo[1]'
	info[0].sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
	info[0].flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT
	info[0].queueFamilyIndex = queueFamilyIndices.graphicsFamily
	self.id = vkGet('VkCommandPool', vkassert, vk.vkCreateCommandPool, device.id, info, nil)

	self.device = device.id
	self.graphicsQueue = device.graphicsQueue
end

function VKCommandPool:transitionImageLayout(image, oldLayout, newLayout, mipLevels)
	VKSingleTimeCommand(self.device, self.graphicsQueue, self.id,
	function(commandBuffer)
		local barrier = ffi.new'VkImageMemoryBarrier[1]'
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

function VKCommandPool:copyBuffer(srcBuffer, dstBuffer, size)
	VKSingleTimeCommand(self.device, self.graphicsQueue, self.id,
	function(commandBuffer)
		local regions = ffi.new'VkBufferCopy[1]'
		regions[0].size = size
		vk.vkCmdCopyBuffer(
			commandBuffer,
			srcBuffer,
			dstBuffer,
			1,
			regions
		)
	end)
end

function VKCommandPool:copyBufferToImage(buffer, image, width, height)
	VKSingleTimeCommand(self.device, self.graphicsQueue, self.id,
	function(commandBuffer)
		local regions = ffi.new'VkBufferImageCopy[1]'
		regions[0].imageSubresource.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT
		regions[0].imageSubresource.layerCount = 1
		regions[0].imageExtent.width = width
		regions[0].imageExtent.height = height
		regions[0].imageExtent.depth = 1
		vk.vkCmdCopyBufferToImage(
			commandBuffer,
			buffer,
			image,
			vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
			1,
			regions
		)
	end)
end


local VKDeviceMemoryBuffer = class()

function VKDeviceMemoryBuffer:init(physDev, device, size, usage, properties)
	local info = ffi.new'VkBufferCreateInfo[1]'
	info[0].sType = vk.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO
	info[0].flags = 0
	info[0].size = size
	info[0].usage = usage
	info[0].sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE
	local buffer = vkGet('VkBuffer', vkassert, vk.vkCreateBuffer, device, info, nil)

	local memReq = vkGet('VkMemoryRequirements', nil, vk.vkGetBufferMemoryRequirements, device, buffer)

	local info = ffi.new'VkMemoryAllocateInfo[1]'
	info[0].allocationSize = memReq.size
	info[0].memoryTypeIndex = physDev:findMemoryType(memReq.memoryTypeBits, properties)
	local memory = vkGet('VkDeviceMemory', vkassert, vk.vkAllocateMemory, device, info, nil)

	vkassert(vk.vkBindBufferMemory, device, buffer, memory, 0)

	self.buffer = buffer
	self.memory = memory
end

function VKDeviceMemoryBuffer:makeBufferFromStaged(physDev, device, commandPool, srcData, bufferSize)
	-- TODO esp this, is a raii ,and should free upon dtor upon scope end
	local stagingBufferAndMemory = VKDeviceMakeFromStagingBuffer:create(
		physDev,
		device,
		srcData,
		bufferSize
	)

	local bufferAndMemory = VKDeviceMemoryBuffer(
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

	return bufferAndMemory
end


local VKBufferMemoryAndMapped = class()

function VKBufferMemoryAndMapped:init(bm, mapped)
	self.bm = bm
	self.mapped = mapped
end


local VKMesh = class()

function VKMesh:init(physDev, device, commandPool)
	local ObjLoader = require 'mesh.objloader'
	local mesh = ObjLoader():load"viking_room.obj";

	local indices = mesh.triIndexes	-- vector'int32_t'
	asserteq(indices.type, 'int32_t') 	-- well, uint, but whatever
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

	local vertexBufferAndMemory = VKDeviceMemoryBuffer:makeBufferFromStaged(
		physDev,
		device.id,
		commandPool,
		vertices.v,
		#vertices * ffi.sizeof(vertices.type)
	)

	local numIndices = #indices
	local indexBufferAndMemory = VKDeviceMemoryBuffer:makeBufferFromStaged(
		physDev,
		device.id,
		commandPool,
		indices.v,
		#indices * ffi.sizeof(indices.type)
	)

	self.vertexBufferAndMemory = vertexBufferAndMemory
	self.indexBufferAndMemory = indexBufferAndMemory
	self.numIndices = numIndices
end


local VKCommon = class()

VKCommon.enableValidationLayers = false
VKCommon.maxFramesInFlight = 2

function VKCommon:init(app)
	self.framebufferResized = false
	self.currentFrame = 0

	assert(not self.enableValidationLayers or self:checkValidationLayerSupport(), "validation layers requested, but not available!")
	self.instance = VKInstance(app, self.enableValidationLayers)

	self.surface = vkGet('VkSurfaceKHR', sdlvksafe, sdl.SDL_Vulkan_CreateSurface, app.window, self.instance.id)

	local deviceExtensions = vector'char const *'
	deviceExtensions:emplace_back()[0] = VK_KHR_SWAPCHAIN_EXTENSION_NAME

	self.physDev = VKPhysicalDevice(self.instance.id, self.surface, deviceExtensions)

	self.msaaSamples = self.physDev:getMaxUsableSampleCount()
print('msaaSamples', self.msaaSamples)

	self.device = VKDevice(
		self.physDev.id,
		deviceExtensions,
		enableValidationLayers,
		self.physDev:findQueueFamilies(nil, self.surface)
	)

	self.swapChain = self:createSwapChain(app)

	self.graphicsPipeline = VKGraphicsPipeline(self.physDev, self.device.id, self.swapChain.renderPass, self.msaaSamples)

	self.commandPool = VKCommandPool(self.physDev, self.device, self.surface)

	self.textureImageAndMemory = self:createTextureImage()

	self.textureImageView = self.swapChain:createImageView(
		self.device.id,
		self.textureImageAndMemory.image,
		vk.VK_FORMAT_R8G8B8A8_SRGB,
		vk.VK_IMAGE_ASPECT_COLOR_BIT,
		self.mipLevels)

	local info = ffi.new'VkSamplerCreateInfo[1]'
	info[0].magFilter = vk.VK_FILTER_LINEAR
	info[0].minFilter = vk.VK_FILTER_LINEAR
	info[0].mipmapMode = vk.VK_SAMPLER_MIPMAP_MODE_LINEAR
	info[0].addressModeU = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT
	info[0].addressModeV = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT
	info[0].addressModeW = vk.VK_SAMPLER_ADDRESS_MODE_REPEAT
	info[0].anisotropyEnable = vk.VK_TRUE
	info[0].maxAnisotropy = self.physDev:getProps().limits.maxSamplerAnisotropy
	info[0].compareEnable = vk.VK_FALSE
	info[0].compareOp = vk.VK_COMPARE_OP_ALWAYS
	info[0].minLod = 0
	info[0].maxLod = self.mipLevels
	info[0].borderColor = vk.VK_BORDER_COLOR_INT_OPAQUE_BLACK
	info[0].unnormalizedCoordinates = vk.VK_FALSE
	self.textureSampler = vkGet('VkSampler', vkassert, vk.vkCreateSampler, self.device.id, info, nil)

	self.mesh = VKMesh(self.physDev, self.device, self.commandPool)

	self.uniformBuffers = range(self.maxFramesInFlight):mapi(function(i)
		local size = ffi.sizeof'UniformBufferObject'
		local bm = VKDeviceMemoryBuffer(
			self.physDev,
			self.device.id,
			size,
			vk.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
			bit.bor(
				vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
				vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
			)
		)
		local mapped = vkGet('void*', vkassert, vk.vkMapMemory, self.device.id, bm.memory, 0, size, 0)
		return VKBufferMemoryAndMapped(bm, mapped)
	end)

	local poolSizes = vector'VkDescriptorPoolSize'
	local p = poolSizes:emplace_back()
	p[0].type = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
	p[0].descriptorCount = self.maxFramesInFlight
	local p = poolSizes:emplace_back()
	p[0].type = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
	p[0].descriptorCount = self.maxFramesInFlight

	local info = ffi.new'VkDescriptorPoolCreateInfo[1]'
	info[0].sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO
	info[0].maxSets = self.maxFramesInFlight
	info[0].poolSizeCount = #poolSizes
	info[0].pPoolSizes = poolSizes.v
	self.descriptorPool = vkGet('VkDescriptorPool', vkassert, vk.vkCreateDescriptorPool, self.device.id, info, nil)

	self.descriptorSets = self:createDescriptorSets()

	local info = ffi.new'VkCommandBufferAllocateInfo[1]'
	info[0].sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
	info[0].commandPool = self.commandPool.id
	info[0].level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY
	info[0].commandBufferCount = self.maxFramesInFlight
	self.commandBuffers = vkGet('VkCommandBuffer', vkassert, vk.vkAllocateCommandBuffers, self.device.id, info)

	self.imageAvailableSemaphores = vector'VkSemaphore'
	for i=0,self.maxFramesInFlight-1 do
		local info = ffi.new'VkSemaphoreCreateInfo[1]'
		info[0].sType = vk.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
		self.imageAvailableSemaphores:push_back(vkGet('VkSemaphore', vkassert, vk.vkCreateSemaphore, self.device.id, info, nil))
	end

	self.renderFinishedSemaphores = vector'VkSemaphore'
	for i=0,self.maxFramesInFlight-1 do
		local info = ffi.new'VkSemaphoreCreateInfo[1]'
		info[0].sType = vk.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
		self.renderFinishedSemaphores:push_back(vkGet('VkSemaphore', vkassert, vk.vkCreateSemaphore, self.device.id, info, nil))
	end

	self.inFlightFences = vector'VkFence'
	for i=0,self.maxFramesInFlight-1 do
		local info = ffi.new'VkFenceCreateInfo[1]'
		info[0].sType = vk.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO
		info[0].flags = vk.VK_FENCE_CREATE_SIGNALED_BIT
		self.inFlightFences:push_back(vkGet('VkFence', vkassert, vk.vkCreateFence, self.device.id, info, nil))
	end
end

function VKCommon:createSwapChain(app)
	return VKSwapchain(
		app.width,
		app.height,
		self.physDev,
		self.device.id,
		self.surface,
		self.msaaSamples)
end

function VKCommon:createTextureImage()
	local texturePath = 'viking_room.png'
	local Image = require 'image'
	local image = assert(Image(texturePath))
	image = image:setChannels(4)
	assert(image.channels == 4)	-- TODO setChannels
	local bufferSize = image.width * image.height * image.channels

	-- TODO why store in 'self', why not store with 'textureImageAndMemory' and 'textureImageView' all in one place?
	self.mipLevels = math.floor(math.log(math.max(image.width, image.height), 2)) + 1
	local textureImageAndMemory = VKDeviceMemoryImage:makeTextureFromStaged(
		self.physDev,
		self.device.id,
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

function VKCommon:generateMipmaps(image, imageFormat, texWidth, texHeight, mipLevels)
	local formatProperties = self.physDev:getFormatProps(nil, imageFormat)

	if 0 == bit.band(formatProperties.optimalTilingFeatures, vk.VK_FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_LINEAR_BIT) then
		error "texture image format does not support linear blitting!"
	end

	VKSingleTimeCommand(self.device.id, self.device.graphicsQueue, self.commandPool.id,
	function(commandBuffer)
		local barrier = ffi.new'VkImageMemoryBarrier[1]'
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

			local blit = ffi.new'VkImageBlit[1]'
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

function VKCommon:createDescriptorSets()
	local layouts = vector'VkDescriptorSetLayout'
	for i=1,self.maxFramesInFlight do
		layouts:push_back(self.graphicsPipeline.descriptorSetLayout)
	end

	local info = ffi.new'VkDescriptorSetAllocateInfo[1]'
	info[0].sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO
	info[0].descriptorPool = self.descriptorPool
	info[0].descriptorSetCount = #layouts -- self.maxFramesInFlight
	info[0].pSetLayouts = layouts.v	-- length matches descriptorSetCount I think?

	--[[ vkGet just allocates one
	-- vkGetVector expects a 'count' field to determine size
	-- ... we have to statically allocate for this function ...
	local descriptorSets = vkGet('VkDescriptorSet',
		vkassert,
		vk.vkAllocateDescriptorSets,
		self.device.id,
		info
	)
	--]]
	-- [[
	local descriptorSets = vector'VkDescriptorSet'
	descriptorSets:resize(self.maxFramesInFlight)
	vkassert(vk.vkAllocateDescriptorSets, self.device.id, info, descriptorSets.v)
	--]]

	for i=0,self.maxFramesInFlight-1 do
		local bufferInfo = ffi.new'VkDescriptorBufferInfo[1]'
		bufferInfo[0].buffer = self.uniformBuffers[i+1].buffer
		bufferInfo[0].range = ffi.sizeof'UniformBufferObject'

		local imageInfo = ffi.new'VkDescriptorImageInfo[1]'
		imageInfo[0].sampler = self.textureSampler
		imageInfo[0].imageView = self.textureImageView
		imageInfo[0].imageLayout = vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL

		local descriptorWrites = vector'VkWriteDescriptorSet'
		local d = descriptorWrites:emplace_back()
		d[0].sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
		d[0].dstSet = descriptorSets.v[i]
		d[0].dstBinding = 0
		d[0].descriptorCount = 1
		d[0].descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
		d[0].pBufferInfo = bufferInfo

		local d = descriptorWrites:emplace_back()
		d[0].dstSet = descriptorSets.v[i]
		d[0].dstBinding = 1
		d[0].descriptorCount = 1
		d[0].descriptorType = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
		d[0].pImageInfo = imageInfo

		vk.vkUpdateDescriptorSets(
			self.device.id,
			#descriptorWrites,
			descriptorWrites.v,
			0,
			nil)
	end

	return descriptorSets
end

function VKCommon:setFramebufferResized()
	self.framebufferResized = true
end

function VKCommon:drawFrame()

end

function VKCommon:exit()
	vk.vkDestroySurfaceKHR(self.instance.id, self.surface, nil)
	self.instance:destroy()
	--self.device:waitIdle()
end
--]]

-- [[ VulkanApp
local SDLApp = require 'sdl.app'	-- TODO sdl.app ?  and gl.app and imgui.app ?

local VulkanApp = SDLApp:subclass()

VulkanApp.title = 'Vulkan test'
VulkanApp.sdlCreateWindowFlags = bit.bor(VulkanApp.sdlCreateWindowFlags, sdl.SDL_WINDOW_VULKAN)

function VulkanApp:initWindow()
	VulkanApp.super.initWindow(self)
	self.vkCommon = VKCommon(self)
print('VulkanApp:initWindow done')
end

function VulkanApp:postUpdate()
	self.vkCommon:drawFrame()
	VulkanApp.super.postUpdate(self)
end

function VKCommon:resize()
	self.vkCommon:setFramebufferResized()
end

function VulkanApp:exit()
	self.vkCommon:exit()

	VulkanApp.super.exit(self)
end

return VulkanApp
