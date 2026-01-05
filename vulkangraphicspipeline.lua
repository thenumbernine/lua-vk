-- helper not wrapper
local ffi = require 'ffi'
local class = require 'ext.class'
local vector = require 'ffi.cpp.vector-lua'
local vec3f = require 'vec-ffi.vec3f'
local struct = require 'struct'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local VulkanShaderModule = require 'vk.vulkanshadermodule'


local VkPipelineShaderStageCreateInfo = ffi.typeof'VkPipelineShaderStageCreateInfo'
local VkDynamicState = ffi.typeof'VkDynamicState'
local VkVertexInputBindingDescription = ffi.typeof'VkVertexInputBindingDescription'
local VkDescriptorSetLayout = ffi.typeof'VkDescriptorSetLayout'
local VkPipelineLayout = ffi.typeof'VkPipelineLayout'
local VkPipeline = ffi.typeof'VkPipeline'
local VkDescriptorSetLayoutBinding = ffi.typeof'VkDescriptorSetLayoutBinding'
local VkDescriptorSetLayoutCreateInfo_1 = ffi.typeof'VkDescriptorSetLayoutCreateInfo[1]'
local VkPipelineVertexInputStateCreateInfo_1 = ffi.typeof'VkPipelineVertexInputStateCreateInfo[1]'
local VkPipelineInputAssemblyStateCreateInfo_1 = ffi.typeof'VkPipelineInputAssemblyStateCreateInfo[1]'
local VkPipelineViewportStateCreateInfo_1 = ffi.typeof'VkPipelineViewportStateCreateInfo[1]'
local VkPipelineRasterizationStateCreateInfo_1 = ffi.typeof'VkPipelineRasterizationStateCreateInfo[1]'
local VkPipelineMultisampleStateCreateInfo_1 = ffi.typeof'VkPipelineMultisampleStateCreateInfo[1]'
local VkPipelineDepthStencilStateCreateInfo_1 = ffi.typeof'VkPipelineDepthStencilStateCreateInfo[1]'
local VkPipelineColorBlendAttachmentState_1 = ffi.typeof'VkPipelineColorBlendAttachmentState[1]'
local VkPipelineColorBlendStateCreateInfo_1 = ffi.typeof'VkPipelineColorBlendStateCreateInfo[1]'
local VkPipelineDynamicStateCreateInfo_1 = ffi.typeof'VkPipelineDynamicStateCreateInfo[1]'
local VkPipelineLayoutCreateInfo_1 = ffi.typeof'VkPipelineLayoutCreateInfo[1]'
local VkGraphicsPipelineCreateInfo_1 = ffi.typeof'VkGraphicsPipelineCreateInfo[1]'
local VkVertexInputAttributeDescription = ffi.typeof'VkVertexInputAttributeDescription'


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

return VulkanGraphicsPipeline 
