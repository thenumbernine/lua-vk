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
local VkDescriptorSetLayoutBinding_array = ffi.typeof'VkDescriptorSetLayoutBinding[?]'
local VkDescriptorSetLayoutCreateInfo = ffi.typeof'VkDescriptorSetLayoutCreateInfo'
local VkDynamicState_array = ffi.typeof'VkDynamicState[?]'
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
local VkPipelineShaderStageCreateInfo_array = ffi.typeof'VkPipelineShaderStageCreateInfo[?]'
local VkPipelineVertexInputStateCreateInfo = ffi.typeof'VkPipelineVertexInputStateCreateInfo'
local VkPipelineViewportStateCreateInfo = ffi.typeof'VkPipelineViewportStateCreateInfo'
local VkDescriptorSetLayout_1 = ffi.typeof'VkDescriptorSetLayout[1]'
local VkVertexInputBindingDescription_1 = ffi.typeof'VkVertexInputBindingDescription[1]'


local VulkanGraphicsPipeline = class()

function VulkanGraphicsPipeline:init(physDev, device, renderPass, msaaSamples)
	-- descriptorSetLayout is only used by graphicsPipeline
	local numBindings = 2
	local bindings = VkDescriptorSetLayoutBinding_array(numBindings)
	local v = bindings+0
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
	asserteq(v, bindings + numBindings)

	local info = VkDescriptorSetLayoutCreateInfo()
	info.sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO
	info.bindingCount = numBindings
	info.pBindings = bindings
	self.descriptorSetLayout = vkGet(
		VkDescriptorSetLayout,
		nil,
		vk.vkCreateDescriptorSetLayout,
		device,
		info,
		nil
	)


	local bindingDescription = VulkanVertex:getBindingDescription()
	local bindingDescriptions = VkVertexInputBindingDescription_1(bindingDescription)

	local attributeDescriptions = VulkanVertex:getAttributeDescriptions()
	local vertexInputInfo = VkPipelineVertexInputStateCreateInfo()
	vertexInputInfo.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
	vertexInputInfo.vertexBindingDescriptionCount = 1
	vertexInputInfo.pVertexBindingDescriptions = bindingDescriptions
	vertexInputInfo.vertexAttributeDescriptionCount = #attributeDescriptions
	vertexInputInfo.pVertexAttributeDescriptions = attributeDescriptions.v

	local inputAssembly = VkPipelineInputAssemblyStateCreateInfo()
	inputAssembly.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
	inputAssembly.topology = vk.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
	inputAssembly.primitiveRestartEnable = vk.VK_FALSE

	local viewportState = VkPipelineViewportStateCreateInfo()
	viewportState.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO
	viewportState.viewportCount = 1
	viewportState.scissorCount = 1

	local rasterizer = VkPipelineRasterizationStateCreateInfo()
	rasterizer.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO
	rasterizer.depthClampEnable = vk.VK_FALSE
	rasterizer.rasterizerDiscardEnable = vk.VK_FALSE
	rasterizer.polygonMode = vk.VK_POLYGON_MODE_FILL
	--rasterizer.cullMode = vk::CullModeFlagBits::eBack
	--rasterizer.frontFace = vk::FrontFace::eClockwise
	--rasterizer.frontFace = vk::FrontFace::eCounterClockwise
	rasterizer.depthBiasEnable = vk.VK_FALSE
	rasterizer.lineWidth = 1

	local multisampling = VkPipelineMultisampleStateCreateInfo()
	multisampling.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
	multisampling.rasterizationSamples = msaaSamples
	multisampling.sampleShadingEnable = vk.VK_FALSE

	local depthStencil = VkPipelineDepthStencilStateCreateInfo()
	depthStencil.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO
	depthStencil.depthTestEnable = vk.VK_TRUE
	depthStencil.depthWriteEnable = vk.VK_TRUE
	depthStencil.depthCompareOp = vk.VK_COMPARE_OP_LESS
	depthStencil.depthBoundsTestEnable = vk.VK_FALSE
	depthStencil.stencilTestEnable = vk.VK_FALSE

	local colorBlendAttachment = VkPipelineColorBlendAttachmentState()
	colorBlendAttachment.blendEnable = vk.VK_FALSE
	colorBlendAttachment.colorWriteMask = bit.bor(
		vk.VK_COLOR_COMPONENT_R_BIT,
		vk.VK_COLOR_COMPONENT_G_BIT,
		vk.VK_COLOR_COMPONENT_B_BIT,
		vk.VK_COLOR_COMPONENT_A_BIT
	)

	local colorBlending = VkPipelineColorBlendStateCreateInfo()
	colorBlending.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
	colorBlending.logicOpEnable = vk.VK_FALSE
	colorBlending.logicOp = vk.VK_LOGIC_OP_COPY
	colorBlending.attachmentCount = 1
	colorBlending.pAttachments = colorBlendAttachment
	colorBlending.blendConstants[0] = 0
	colorBlending.blendConstants[1] = 0
	colorBlending.blendConstants[2] = 0
	colorBlending.blendConstants[3] = 0

	local numDynamicStates = 2
	local dynamicStates = VkDynamicState_array(numDynamicStates)
	dynamicStates[0] = vk.VK_DYNAMIC_STATE_VIEWPORT
	dynamicStates[1] = vk.VK_DYNAMIC_STATE_SCISSOR
	local dynamicState = VkPipelineDynamicStateCreateInfo()
	dynamicState.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO
	dynamicState.dynamicStateCount = numDynamicStates
	dynamicState.pDynamicStates = dynamicStates

	local descriptorSetLayouts = VkDescriptorSetLayout_1(self.descriptorSetLayout)

	local info = VkPipelineLayoutCreateInfo()
	info.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
	info.setLayoutCount = 1
	info.pSetLayouts = descriptorSetLayouts
	self.pipelineLayout = vkGet(VkPipelineLayout, vkassert, vk.vkCreatePipelineLayout, device, info, nil)
	-- but save self.descriptorSetLayout for later

	self.vertexShaderModule = VulkanShaderModule:fromFile(device, "shader-vert.spv")
	self.fragmentShaderModule = VulkanShaderModule:fromFile(device, "shader-frag.spv")
	local numShaderStages = 2
	local shaderStages = VkPipelineShaderStageCreateInfo_array(numShaderStages)
	local v = shaderStages+0
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
	asserteq(v, shaderStages + numShaderStages)

	local info = VkGraphicsPipelineCreateInfo()
	info.sType = vk.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO
	info.stageCount = numShaderStages
	info.pStages = shaderStages
	info.pVertexInputState = vertexInputInfo
	info.pInputAssemblyState = inputAssembly
	info.pViewportState = viewportState
	info.pRasterizationState = rasterizer
	info.pMultisampleState = multisampling
	info.pDepthStencilState = depthStencil
	info.pColorBlendState = colorBlending
	info.pDynamicState = dynamicState
	info.layout = self.pipelineLayout
	info.renderPass = renderPass
	info.subpass = 0

	--info.basePipelineHandle = {}
	self.id = vkGet(VkPipeline, vkassert, vk.vkCreateGraphicsPipelines, device, nil, 1, info, nil)

	-- keep self.pipelineLayout
	-- keep self.fragmentShaderModule
	-- keep self.vertexShaderModule
end

function VulkanGraphicsPipeline:destroy(device)
	if self.descriptorSetLayout then
		vk.vkDestroyDescriptorSetLayout(device, self.descriptorSetLayout, nil)
	end
	if self.pipelineLayout then
		vk.vkDestroyPipelineLayout(device, self.pipelineLayout, nil)
	end
	if self.vertexShaderModule then
		vk.vkDestroyShaderModule(device, self.vertexShaderModule, nil)
	end
	if self.fragmentShaderModule then
		vk.vkDestroyShaderModule(device, self.fragmentShaderModule, nil)
	end
	if self.id then
		vk.vkDestroyPipeline(device, self.id, nil)
	end
	self.descriptorSetLayout = nil
	self.pipelineLayout = nil
	self.vertexShaderModule = nil
	self.fragmentShaderModule = nil
	self.id = nil
end

return VulkanGraphicsPipeline 
