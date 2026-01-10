-- helper not wrapper
local ffi = require 'ffi'
local class = require 'ext.class'
local asserteq = require 'ext.assert'.eq
local vk = require 'vk'
local defs = require 'vk.defs'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local VulkanShaderModule = require 'vk.vulkanshadermodule'
local VulkanVertex = require 'vk.vulkanmesh'.VulkanVertex

defs.main = 'main'

local VkDescriptorSetLayout = ffi.typeof'VkDescriptorSetLayout'
local VkDescriptorSetLayout_1 = ffi.typeof'VkDescriptorSetLayout[1]'
local VkDescriptorSetLayoutBinding = ffi.typeof'VkDescriptorSetLayoutBinding'
local VkDescriptorSetLayoutCreateInfo_1 = ffi.typeof'VkDescriptorSetLayoutCreateInfo[1]'
local VkDynamicState = ffi.typeof'VkDynamicState'
local VkGraphicsPipelineCreateInfo_1 = ffi.typeof'VkGraphicsPipelineCreateInfo[1]'
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
local VkPipelineVertexInputStateCreateInfo_1 = ffi.typeof'VkPipelineVertexInputStateCreateInfo[1]'
local VkPipelineViewportStateCreateInfo_1 = ffi.typeof'VkPipelineViewportStateCreateInfo[1]'
local VkVertexInputBindingDescription_1 = ffi.typeof'VkVertexInputBindingDescription[1]'


local VulkanGraphicsPipeline = class()

function VulkanGraphicsPipeline:init(physDev, device, renderPass, msaaSamples)
	-- descriptorSetLayout is only used by graphicsPipeline
	local numBindings = 2
	self.bindings = ffi.new(ffi.typeof('$[?]', VkDescriptorSetLayoutBinding), numBindings)
	local v = self.bindings+0
	--uboLayoutBinding
	v.binding = 0
	v.descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
	v.descriptorCount = 1
	v.stageFlags = vk.VK_SHADER_STAGE_VERTEX_BIT
	v=v+1
		--samplerLayoutBinding
	v.binding = 1
	v.descriptorType = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
	v.descriptorCount = 1
	v.stageFlags = vk.VK_SHADER_STAGE_FRAGMENT_BIT
	v=v+1
	asserteq(v, self.bindings + numBindings)

	self.info = VkDescriptorSetLayoutCreateInfo_1()
	self.info[0].sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO
	self.info[0].bindingCount = numBindings
	self.info[0].pBindings = self.bindings
	self.descriptorSetLayout = vkGet(
		VkDescriptorSetLayout,
		nil,
		vk.vkCreateDescriptorSetLayout,
		device,
		self.info,
		nil
	)
	self.info = nil
	self.bindings = nil


	self.bindingDescription = VulkanVertex:getBindingDescription()
	self.bindingDescriptions = VkVertexInputBindingDescription_1()
	self.bindingDescriptions[0] = self.bindingDescription

	self.attributeDescriptions = VulkanVertex:getAttributeDescriptions()
	self.vertexInputInfo = VkPipelineVertexInputStateCreateInfo_1()
	self.vertexInputInfo[0].sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
	self.vertexInputInfo[0].vertexBindingDescriptionCount = 1
	self.vertexInputInfo[0].pVertexBindingDescriptions = self.bindingDescriptions
	self.vertexInputInfo[0].vertexAttributeDescriptionCount = #self.attributeDescriptions
	self.vertexInputInfo[0].pVertexAttributeDescriptions = self.attributeDescriptions.v

	self.inputAssembly = VkPipelineInputAssemblyStateCreateInfo_1()
	self.inputAssembly[0].topology = vk.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
	self.inputAssembly[0].primitiveRestartEnable = vk.VK_FALSE

	self.viewportState = VkPipelineViewportStateCreateInfo_1()
	self.viewportState[0].viewportCount = 1
	self.viewportState[0].scissorCount = 1

	self.rasterizer = VkPipelineRasterizationStateCreateInfo_1()
	self.rasterizer[0].depthClampEnable = vk.VK_FALSE
	self.rasterizer[0].rasterizerDiscardEnable = vk.VK_FALSE
	self.rasterizer[0].polygonMode = vk.VK_POLYGON_MODE_FILL
	--self.rasterizer[0].cullMode = vk::CullModeFlagBits::eBack
	--self.rasterizer[0].frontFace = vk::FrontFace::eClockwise
	--self.rasterizer[0].frontFace = vk::FrontFace::eCounterClockwise
	self.rasterizer[0].depthBiasEnable = vk.VK_FALSE
	self.rasterizer[0].lineWidth = 1

	self.multisampling = VkPipelineMultisampleStateCreateInfo_1()
	self.multisampling[0].rasterizationSamples = msaaSamples
	self.multisampling[0].sampleShadingEnable = vk.VK_FALSE

	self.depthStencil = VkPipelineDepthStencilStateCreateInfo_1()
	self.depthStencil[0].depthTestEnable = vk.VK_TRUE
	self.depthStencil[0].depthWriteEnable = vk.VK_TRUE
	self.depthStencil[0].depthCompareOp = vk.VK_COMPARE_OP_LESS
	self.depthStencil[0].depthBoundsTestEnable = vk.VK_FALSE
	self.depthStencil[0].stencilTestEnable = vk.VK_FALSE

	self.colorBlendAttachment = VkPipelineColorBlendAttachmentState_1()
	self.colorBlendAttachment[0].blendEnable = vk.VK_FALSE
	self.colorBlendAttachment[0].colorWriteMask = bit.bor(
		vk.VK_COLOR_COMPONENT_R_BIT,
		vk.VK_COLOR_COMPONENT_G_BIT,
		vk.VK_COLOR_COMPONENT_B_BIT,
		vk.VK_COLOR_COMPONENT_A_BIT
	)

	self.colorBlending = VkPipelineColorBlendStateCreateInfo_1()
	self.colorBlending[0].logicOpEnable = vk.VK_FALSE
	self.colorBlending[0].logicOp = vk.VK_LOGIC_OP_COPY
	self.colorBlending[0].attachmentCount = 1
	self.colorBlending[0].pAttachments = self.colorBlendAttachment
	self.colorBlending[0].blendConstants = {0, 0, 0, 0}

	local numDynamicStates = 2
	self.dynamicStates = ffi.new(ffi.typeof('$[?]', VkDynamicState), numDynamicStates)
	self.dynamicStates[0] = vk.VK_DYNAMIC_STATE_VIEWPORT
	self.dynamicStates[1] = vk.VK_DYNAMIC_STATE_SCISSOR
	self.dynamicState = VkPipelineDynamicStateCreateInfo_1()
	self.dynamicState[0].dynamicStateCount = numDynamicStates
	self.dynamicState[0].pDynamicStates = self.dynamicStates

	self.descriptorSetLayouts = VkDescriptorSetLayout_1()
	self.descriptorSetLayouts[0] = self.descriptorSetLayout
	self.info = VkPipelineLayoutCreateInfo_1()
	self.info[0].sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
	self.info[0].setLayoutCount = 1
	self.info[0].pSetLayouts = self.descriptorSetLayouts
	self.pipelineLayout = vkGet(VkPipelineLayout, vkassert, vk.vkCreatePipelineLayout, device, self.info, nil)
	self.info = nil
	self.descriptorSetLayouts = nil
	-- but save self.descriptorSetLayout for later

	self.vertexShaderModule = VulkanShaderModule:fromFile(device, "shader-vert.spv")
	self.fragmentShaderModule = VulkanShaderModule:fromFile(device, "shader-frag.spv")
	local numShaderStages = 2
	self.shaderStages = ffi.new(ffi.typeof('$[?]', VkPipelineShaderStageCreateInfo), numShaderStages)
	local v = self.shaderStages+0
	v.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
	v.stage = vk.VK_SHADER_STAGE_VERTEX_BIT
	v.module = self.vertexShaderModule
	v.pName = defs.main	--'vert'	--GLSL uses 'main', but clspv doesn't allow 'main', so ...
	v=v+1
	v.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
	v.stage = vk.VK_SHADER_STAGE_FRAGMENT_BIT
	v.module = self.fragmentShaderModule
	v.pName = defs.main	--'frag'
	v=v+1
	asserteq(v, self.shaderStages+numShaderStages)

	self.info = VkGraphicsPipelineCreateInfo_1()
	self.info[0].sType = vk.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO
	self.info[0].stageCount = numShaderStages
	self.info[0].pStages = self.shaderStages
	self.info[0].pVertexInputState = self.vertexInputInfo
	self.info[0].pInputAssemblyState = self.inputAssembly
	self.info[0].pViewportState = self.viewportState
	self.info[0].pRasterizationState = self.rasterizer
	self.info[0].pMultisampleState = self.multisampling
	self.info[0].pDepthStencilState = self.depthStencil
	self.info[0].pColorBlendState = self.colorBlending
	self.info[0].pDynamicState = self.dynamicState
	self.info[0].layout = self.pipelineLayout
	self.info[0].renderPass = renderPass
	self.info[0].subpass = 0

	--self.info[0].basePipelineHandle = {}
	self.id = vkGet(VkPipeline, vkassert, vk.vkCreateGraphicsPipelines, device, nil, 1, self.info, nil)

	self.info = nil
	self.shaderStages = nil
	self.fragmentShaderModule = nil
	self.vertexShaderModule = nil
	self.pipelineLayout = nil
	self.dynamicState = nil
	self.dynamicStates = nil
	self.colorBlending = nil
	self.colorBlendAttachment = nil
	self.depthStencil = nil
	self.multisampling = nil
	self.rasterizer = nil
	self.viewportState = nil
	self.inputAssembly = nil
	self.vertexInputInfo = nil
	self.attributeDescriptions = nil
	self.bindingDescriptions = nil
	self.bindingDescription = nil
end

return VulkanGraphicsPipeline 
