-- helper not wrapper
local ffi = require 'ffi'
local class = require 'ext.class'
local vector = require 'ffi.cpp.vector-lua'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local VulkanShaderModule = require 'vk.vulkanshadermodule'
local Vertex = require 'vk.vulkanmesh'.Vertex


local VkDescriptorSetLayout = ffi.typeof'VkDescriptorSetLayout'
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
local VkVertexInputBindingDescription = ffi.typeof'VkVertexInputBindingDescription'


local VulkanGraphicsPipeline = class()

function VulkanGraphicsPipeline:init(physDev, device, renderPass, msaaSamples)
	-- descriptorSetLayout is only used by graphicsPipeline
	self.bindings = vector(VkDescriptorSetLayoutBinding, {
		{ --uboLayoutBinding
			binding = 0,
			descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
			descriptorCount = 1,
			stageFlags = vk.VK_SHADER_STAGE_VERTEX_BIT,
		},
		{--samplerLayoutBinding
			binding = 1,
			descriptorType = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
			descriptorCount = 1,
			stageFlags = vk.VK_SHADER_STAGE_FRAGMENT_BIT,
		},
	})
	self.info = ffi.new(VkDescriptorSetLayoutCreateInfo_1, {{
		sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = #self.bindings,
		pBindings = self.bindings.v,
	}})
	self.descriptorSetLayout = vkGet(VkDescriptorSetLayout, nil, vk.vkCreateDescriptorSetLayout, device, self.info, nil)
	self.info = nil
	self.bindings = nil


	self.bindingDescription = Vertex:getBindingDescription()
	self.bindingDescriptions = vector(VkVertexInputBindingDescription, {
		self.bindingDescription,
	})

	self.attributeDescriptions = Vertex:getAttributeDescriptions()
	self.vertexInputInfo = ffi.new(VkPipelineVertexInputStateCreateInfo_1, {{
		sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		vertexBindingDescriptionCount = #self.bindingDescriptions,
		pVertexBindingDescriptions = self.bindingDescriptions.v,
		vertexAttributeDescriptionCount = #self.attributeDescriptions,
		pVertexAttributeDescriptions = self.attributeDescriptions.v,
	}})

	self.inputAssembly = ffi.new(VkPipelineInputAssemblyStateCreateInfo_1, {{
		topology = vk.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
		primitiveRestartEnable = vk.VK_FALSE,
	}})

	self.viewportState = ffi.new(VkPipelineViewportStateCreateInfo_1, {{
		viewportCount = 1,
		scissorCount = 1,
	}})

	self.rasterizer = ffi.new(VkPipelineRasterizationStateCreateInfo_1, {{
		depthClampEnable = vk.VK_FALSE,
		rasterizerDiscardEnable = vk.VK_FALSE,
		polygonMode = vk.VK_POLYGON_MODE_FILL,
		--cullMode = vk::CullModeFlagBits::eBack,,
		--frontFace = vk::FrontFace::eClockwise,,
		--frontFace = vk::FrontFace::eCounterClockwise,,
		depthBiasEnable = vk.VK_FALSE,
		lineWidth = 1,
	}})

	self.multisampling = ffi.new(VkPipelineMultisampleStateCreateInfo_1, {{
		rasterizationSamples = msaaSamples,
		sampleShadingEnable = vk.VK_FALSE,
	}})

	self.depthStencil = ffi.new(VkPipelineDepthStencilStateCreateInfo_1, {{
		depthTestEnable = vk.VK_TRUE,
		depthWriteEnable = vk.VK_TRUE,
		depthCompareOp = vk.VK_COMPARE_OP_LESS,
		depthBoundsTestEnable = vk.VK_FALSE,
		stencilTestEnable = vk.VK_FALSE,
	}})

	self.colorBlendAttachment = ffi.new(VkPipelineColorBlendAttachmentState_1, {{
		blendEnable = vk.VK_FALSE,
		colorWriteMask = bit.bor(
			vk.VK_COLOR_COMPONENT_R_BIT,
			vk.VK_COLOR_COMPONENT_G_BIT,
			vk.VK_COLOR_COMPONENT_B_BIT,
			vk.VK_COLOR_COMPONENT_A_BIT
		),
	}})

	self.colorBlending = ffi.new(VkPipelineColorBlendStateCreateInfo_1, {{
		logicOpEnable = vk.VK_FALSE,
		logicOp = vk.VK_LOGIC_OP_COPY,
		attachmentCount = 1,
		pAttachments = self.colorBlendAttachment,
		blendConstants = {0, 0, 0, 0},
	}})

	self.dynamicStates = vector(VkDynamicState, {
		vk.VK_DYNAMIC_STATE_VIEWPORT,
		vk.VK_DYNAMIC_STATE_SCISSOR,
	})
	self.dynamicState = ffi.new(VkPipelineDynamicStateCreateInfo_1, {{
		dynamicStateCount = #self.dynamicStates,
		pDynamicStates = self.dynamicStates.v,
	}})

	self.descriptorSetLayouts = vector(VkDescriptorSetLayout, {
		self.descriptorSetLayout,
	})
	self.info = ffi.new(VkPipelineLayoutCreateInfo_1, {{
		sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = #self.descriptorSetLayouts,
		pSetLayouts = self.descriptorSetLayouts.v,
	}})
	self.pipelineLayout = vkGet(VkPipelineLayout, vkassert, vk.vkCreatePipelineLayout, device, self.info, nil)
	self.info = nil
	self.descriptorSetLayouts = nil
	-- but save self.descriptorSetLayout for later

	self.vertexShaderModule = VulkanShaderModule:fromFile(device, "shader-vert.spv")
	self.fragmentShaderModule = VulkanShaderModule:fromFile(device, "shader-frag.spv")
	self.shaderStages = vector(VkPipelineShaderStageCreateInfo, {
		{
			sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage = vk.VK_SHADER_STAGE_VERTEX_BIT,
			module = self.vertexShaderModule,
			pName = 'main',	--'vert'	--GLSL uses 'main', but clspv doesn't allow 'main', so ...
		},
		{
			sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage = vk.VK_SHADER_STAGE_FRAGMENT_BIT,
			module = self.fragmentShaderModule,
			pName = 'main',	--'frag'
		},
	})

	self.info = ffi.new(VkGraphicsPipelineCreateInfo_1, {{
		sType = vk.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
		stageCount = #self.shaderStages,
		pStages = self.shaderStages.v,
		pVertexInputState = self.vertexInputInfo,
		pInputAssemblyState = self.inputAssembly,
		pViewportState = self.viewportState,
		pRasterizationState = self.rasterizer,
		pMultisampleState = self.multisampling,
		pDepthStencilState = self.depthStencil,
		pColorBlendState = self.colorBlending,
		pDynamicState = self.dynamicState,
		layout = self.pipelineLayout,
		renderPass = renderPass,
		subpass = 0,
	}})

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
