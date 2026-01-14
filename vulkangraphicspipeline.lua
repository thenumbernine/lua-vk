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
local VkDescriptorSetLayoutBinding = ffi.typeof'VkDescriptorSetLayoutBinding'
local VkDescriptorSetLayoutCreateInfo = ffi.typeof'VkDescriptorSetLayoutCreateInfo'
local VkDynamicState = ffi.typeof'VkDynamicState'
local VkGraphicsPipelineCreateInfo = ffi.typeof'VkGraphicsPipelineCreateInfo'
local VkPipeline = ffi.typeof'VkPipeline'
local VkPipelineColorBlendAttachmentState = ffi.typeof'VkPipelineColorBlendAttachmentState'
local VkPipelineColorBlendStateCreateInfo = ffi.typeof'VkPipelineColorBlendStateCreateInfo'
local VkPipelineDepthStencilStateCreateInfo = ffi.typeof'VkPipelineDepthStencilStateCreateInfo'
local VkPipelineDynamicStateCreateInfo = ffi.typeof'VkPipelineDynamicStateCreateInfo'
local VkPipelineInputAssemblyStateCreateInfo = ffi.typeof'VkPipelineInputAssemblyStateCreateInfo'
local VkPipelineLayout = ffi.typeof'VkPipelineLayout'
local VkPipelineLayoutCreateInfo = ffi.typeof'VkPipelineLayoutCreateInfo'
local VkPipelineMultisampleStateCreateInfo = ffi.typeof'VkPipelineMultisampleStateCreateInfo'
local VkPipelineRasterizationStateCreateInfo = ffi.typeof'VkPipelineRasterizationStateCreateInfo'
local VkPipelineShaderStageCreateInfo = ffi.typeof'VkPipelineShaderStageCreateInfo'
local VkPipelineVertexInputStateCreateInfo = ffi.typeof'VkPipelineVertexInputStateCreateInfo'
local VkPipelineViewportStateCreateInfo = ffi.typeof'VkPipelineViewportStateCreateInfo'
local VkDescriptorSetLayout_1 = ffi.typeof'VkDescriptorSetLayout[1]'
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

	self.info = VkDescriptorSetLayoutCreateInfo()
	self.info.sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO
	self.info.bindingCount = numBindings
	self.info.pBindings = self.bindings
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
	self.vertexInputInfo = VkPipelineVertexInputStateCreateInfo()
	self.vertexInputInfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
	self.vertexInputInfo.vertexBindingDescriptionCount = 1
	self.vertexInputInfo.pVertexBindingDescriptions = self.bindingDescriptions
	self.vertexInputInfo.vertexAttributeDescriptionCount = #self.attributeDescriptions
	self.vertexInputInfo.pVertexAttributeDescriptions = self.attributeDescriptions.v

	self.inputAssembly = VkPipelineInputAssemblyStateCreateInfo()
	self.inputAssembly.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
	self.inputAssembly.topology = vk.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
	self.inputAssembly.primitiveRestartEnable = vk.VK_FALSE

	self.viewportState = VkPipelineViewportStateCreateInfo()
	self.viewportState.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO
	self.viewportState.viewportCount = 1
	self.viewportState.scissorCount = 1

	self.rasterizer = VkPipelineRasterizationStateCreateInfo()
	self.rasterizer.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO
	self.rasterizer.depthClampEnable = vk.VK_FALSE
	self.rasterizer.rasterizerDiscardEnable = vk.VK_FALSE
	self.rasterizer.polygonMode = vk.VK_POLYGON_MODE_FILL
	--self.rasterizer.cullMode = vk::CullModeFlagBits::eBack
	--self.rasterizer.frontFace = vk::FrontFace::eClockwise
	--self.rasterizer.frontFace = vk::FrontFace::eCounterClockwise
	self.rasterizer.depthBiasEnable = vk.VK_FALSE
	self.rasterizer.lineWidth = 1

	self.multisampling = VkPipelineMultisampleStateCreateInfo()
	self.multisampling.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
	self.multisampling.rasterizationSamples = msaaSamples
	self.multisampling.sampleShadingEnable = vk.VK_FALSE

	self.depthStencil = VkPipelineDepthStencilStateCreateInfo()
	self.depthStencil.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO
	self.depthStencil.depthTestEnable = vk.VK_TRUE
	self.depthStencil.depthWriteEnable = vk.VK_TRUE
	self.depthStencil.depthCompareOp = vk.VK_COMPARE_OP_LESS
	self.depthStencil.depthBoundsTestEnable = vk.VK_FALSE
	self.depthStencil.stencilTestEnable = vk.VK_FALSE

	self.colorBlendAttachment = VkPipelineColorBlendAttachmentState()
	self.colorBlendAttachment.blendEnable = vk.VK_FALSE
	self.colorBlendAttachment.colorWriteMask = bit.bor(
		vk.VK_COLOR_COMPONENT_R_BIT,
		vk.VK_COLOR_COMPONENT_G_BIT,
		vk.VK_COLOR_COMPONENT_B_BIT,
		vk.VK_COLOR_COMPONENT_A_BIT
	)

	self.colorBlending = VkPipelineColorBlendStateCreateInfo()
	self.colorBlending.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
	self.colorBlending.logicOpEnable = vk.VK_FALSE
	self.colorBlending.logicOp = vk.VK_LOGIC_OP_COPY
	self.colorBlending.attachmentCount = 1
	self.colorBlending.pAttachments = self.colorBlendAttachment
	self.colorBlending.blendConstants = {0, 0, 0, 0}

	local numDynamicStates = 2
	self.dynamicStates = ffi.new(ffi.typeof('$[?]', VkDynamicState), numDynamicStates)
	self.dynamicStates[0] = vk.VK_DYNAMIC_STATE_VIEWPORT
	self.dynamicStates[1] = vk.VK_DYNAMIC_STATE_SCISSOR
	self.dynamicState = VkPipelineDynamicStateCreateInfo()
	self.dynamicState.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO
	self.dynamicState.dynamicStateCount = numDynamicStates
	self.dynamicState.pDynamicStates = self.dynamicStates

	self.descriptorSetLayouts = VkDescriptorSetLayout_1()
	self.descriptorSetLayouts[0] = self.descriptorSetLayout

	self.info = VkPipelineLayoutCreateInfo()
	self.info.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
	self.info.setLayoutCount = 1
	self.info.pSetLayouts = self.descriptorSetLayouts
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

	self.info = VkGraphicsPipelineCreateInfo()
	self.info.sType = vk.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO
	self.info.stageCount = numShaderStages
	self.info.pStages = self.shaderStages
	self.info.pVertexInputState = self.vertexInputInfo
	self.info.pInputAssemblyState = self.inputAssembly
	self.info.pViewportState = self.viewportState
	self.info.pRasterizationState = self.rasterizer
	self.info.pMultisampleState = self.multisampling
	self.info.pDepthStencilState = self.depthStencil
	self.info.pColorBlendState = self.colorBlending
	self.info.pDynamicState = self.dynamicState
	self.info.layout = self.pipelineLayout
	self.info.renderPass = renderPass
	self.info.subpass = 0

	--self.info.basePipelineHandle = {}
	self.id = vkGet(VkPipeline, vkassert, vk.vkCreateGraphicsPipelines, device, nil, 1, self.info, nil)

	self.info = nil
	self.shaderStages = nil
	self.fragmentShaderModule = nil
	self.vertexShaderModule = nil
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
	-- keep self.pipelineLayout
end

return VulkanGraphicsPipeline 
