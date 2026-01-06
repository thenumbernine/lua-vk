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
_G.bindings = vector(VkDescriptorSetLayoutBinding, {
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

_G.info = ffi.new(VkDescriptorSetLayoutCreateInfo_1, {{
		sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = #bindings,
		pBindings = bindings.v,
	}})
	self.descriptorSetLayout = vkGet(VkDescriptorSetLayout, nil, vk.vkCreateDescriptorSetLayout, device, info, nil)

_G.bindingDescription = Vertex:getBindingDescription()
_G.bindingDescriptions = vector(VkVertexInputBindingDescription, {
		bindingDescription,
	})

_G.attributeDescriptions = Vertex:getAttributeDescriptions()
_G.vertexInputInfo = ffi.new(VkPipelineVertexInputStateCreateInfo_1, {{
		sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		vertexBindingDescriptionCount = #bindingDescriptions,
		pVertexBindingDescriptions = bindingDescriptions.v,
		vertexAttributeDescriptionCount = #attributeDescriptions,
		pVertexAttributeDescriptions = attributeDescriptions.v,
	}})

_G.inputAssembly = ffi.new(VkPipelineInputAssemblyStateCreateInfo_1, {{
		topology = vk.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
		primitiveRestartEnable = vk.VK_FALSE,
	}})

_G.viewportState = ffi.new(VkPipelineViewportStateCreateInfo_1, {{
		viewportCount = 1,
		scissorCount = 1,
	}})

_G.rasterizer = ffi.new(VkPipelineRasterizationStateCreateInfo_1, {{
		depthClampEnable = vk.VK_FALSE,
		rasterizerDiscardEnable = vk.VK_FALSE,
		polygonMode = vk.VK_POLYGON_MODE_FILL,
		--cullMode = vk::CullModeFlagBits::eBack,,
		--frontFace = vk::FrontFace::eClockwise,,
		--frontFace = vk::FrontFace::eCounterClockwise,,
		depthBiasEnable = vk.VK_FALSE,
		lineWidth = 1,
	}})

_G.multisampling = ffi.new(VkPipelineMultisampleStateCreateInfo_1, {{
		rasterizationSamples = msaaSamples,
		sampleShadingEnable = vk.VK_FALSE,
	}})

_G.depthStencil = ffi.new(VkPipelineDepthStencilStateCreateInfo_1, {{
		depthTestEnable = vk.VK_TRUE,
		depthWriteEnable = vk.VK_TRUE,
		depthCompareOp = vk.VK_COMPARE_OP_LESS,
		depthBoundsTestEnable = vk.VK_FALSE,
		stencilTestEnable = vk.VK_FALSE,
	}})

_G.colorBlendAttachment = ffi.new(VkPipelineColorBlendAttachmentState_1, {{
		blendEnable = vk.VK_FALSE,
		colorWriteMask = bit.bor(
			vk.VK_COLOR_COMPONENT_R_BIT,
			vk.VK_COLOR_COMPONENT_G_BIT,
			vk.VK_COLOR_COMPONENT_B_BIT,
			vk.VK_COLOR_COMPONENT_A_BIT
		),
	}})

_G.colorBlending = ffi.new(VkPipelineColorBlendStateCreateInfo_1, {{
		logicOpEnable = vk.VK_FALSE,
		logicOp = vk.VK_LOGIC_OP_COPY,
		attachmentCount = 1,
		pAttachments = colorBlendAttachment,
		blendConstants = {0, 0, 0, 0},
	}})

_G.dynamicStates = vector(VkDynamicState, {
		vk.VK_DYNAMIC_STATE_VIEWPORT,
		vk.VK_DYNAMIC_STATE_SCISSOR,
	})
_G.dynamicState = ffi.new(VkPipelineDynamicStateCreateInfo_1, {{
		dynamicStateCount = #dynamicStates,
		pDynamicStates = dynamicStates.v,
	}})

_G.descriptorSetLayouts = vector(VkDescriptorSetLayout, {
		self.descriptorSetLayout,
	})
_G.info = ffi.new(VkPipelineLayoutCreateInfo_1, {{
		sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = #descriptorSetLayouts,
		pSetLayouts = descriptorSetLayouts.v,
	}})
_G.pipelineLayout = vkGet(VkPipelineLayout, vkassert, vk.vkCreatePipelineLayout, device, info, nil)

_G.vertShaderModule = VulkanShaderModule:fromFile(device, "shader-vert.spv")
_G.fragShaderModule = VulkanShaderModule:fromFile(device, "shader-frag.spv")
_G.shaderStages = vector(VkPipelineShaderStageCreateInfo, {
		{
			sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage = vk.VK_SHADER_STAGE_VERTEX_BIT,
			module = vertShaderModule,
			pName = 'main',	--'vert'	--GLSL uses 'main', but clspv doesn't allow 'main', so ...
		},
		{
			sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage = vk.VK_SHADER_STAGE_FRAGMENT_BIT,
			module = fragShaderModule,
			pName = 'main',	--'frag'
		},
	})

_G.info = ffi.new(VkGraphicsPipelineCreateInfo_1, {{
		sType = vk.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
		stageCount = #shaderStages,
		pStages = shaderStages.v,
		pVertexInputState = vertexInputInfo,	--why it need to be a pointer?
		pInputAssemblyState = inputAssembly,
		pViewportState = viewportState,
		pRasterizationState = rasterizer,
		pMultisampleState = multisampling,
		pDepthStencilState = depthStencil,
		pColorBlendState = colorBlending,
		pDynamicState = dynamicState,
		layout = pipelineLayout,
		renderPass = renderPass,
		subpass = 0,
	}})

	--info[0].basePipelineHandle = {}
	self.id = vkGet(VkPipeline, vkassert, vk.vkCreateGraphicsPipelines, device, nil, 1, info, nil)
end

return VulkanGraphicsPipeline 
