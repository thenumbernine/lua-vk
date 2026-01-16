-- helper not wrapper
local ffi = require 'ffi'
local class = require 'ext.class'
local asserteq = require 'ext.assert'.eq
local vector = require 'ffi.cpp.vector-lua'
local vk = require 'vk'
local defs = require 'vk.defs'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor
local VKDescriptorSetLayout = require 'vk.descriptorsetlayout'
local VKPipelineLayout = require 'vk.pipelinelayout'
local VKShaderModule = require 'vk.shadermodule'
local VKPipeline = require 'vk.pipeline'
local VulkanVertex = require 'vk.vulkanmesh'.VulkanVertex

defs.main = 'main'

local VkDynamicState_array = ffi.typeof'VkDynamicState[?]'
local VkPipelineColorBlendAttachmentState = ffi.typeof'VkPipelineColorBlendAttachmentState'
local VkPipelineShaderStageCreateInfo_array = ffi.typeof'VkPipelineShaderStageCreateInfo[?]'
local VkDescriptorSetLayout_1 = ffi.typeof'VkDescriptorSetLayout[1]'
local VkVertexInputBindingDescription_1 = ffi.typeof'VkVertexInputBindingDescription[1]'


local makeVkPipelineVertexInputStateCreateInfo = makeStructCtor'VkPipelineVertexInputStateCreateInfo'
local makeVkPipelineInputAssemblyStateCreateInfo = makeStructCtor'VkPipelineInputAssemblyStateCreateInfo'
local makeVkPipelineViewportStateCreateInfo = makeStructCtor'VkPipelineViewportStateCreateInfo'
local makeVkPipelineRasterizationStateCreateInfo = makeStructCtor'VkPipelineRasterizationStateCreateInfo'
local makeVkPipelineMultisampleStateCreateInfo = makeStructCtor'VkPipelineMultisampleStateCreateInfo'
local makeVkPipelineDepthStencilStateCreateInfo = makeStructCtor'VkPipelineDepthStencilStateCreateInfo'
local makeVkPipelineColorBlendStateCreateInfo = makeStructCtor'VkPipelineColorBlendStateCreateInfo'
local makeVkPipelineDynamicStateCreateInfo = makeStructCtor'VkPipelineDynamicStateCreateInfo'
local makeVkPipelineShaderStageCreateInfo = makeStructCtor'VkPipelineShaderStageCreateInfo'


local VulkanGraphicsPipeline = class()

function VulkanGraphicsPipeline:init(physDev, device, renderPass, msaaSamples)
	self.descriptorSetLayout = VKDescriptorSetLayout{
		device = device,
		bindings = {
			--uboLayoutBinding
			{
				binding = 0,
				descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
				descriptorCount = 1,
				stageFlags = vk.VK_SHADER_STAGE_VERTEX_BIT,
			},
			--samplerLayoutBinding
			{
				binding = 1,
				descriptorType = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
				descriptorCount = 1,
				stageFlags = vk.VK_SHADER_STAGE_FRAGMENT_BIT,
			},
		},
	}

	local bindingDescriptions = VkVertexInputBindingDescription_1(
		VulkanVertex:getBindingDescription()
	)

	local attributeDescriptions = VulkanVertex:getAttributeDescriptions()
	local vertexInputInfo = makeVkPipelineVertexInputStateCreateInfo{
		vertexBindingDescriptionCount = 1,
		pVertexBindingDescriptions = bindingDescriptions,
		vertexAttributeDescriptionCount = #attributeDescriptions,
		pVertexAttributeDescriptions = attributeDescriptions.v,
	}

	local inputAssembly = makeVkPipelineInputAssemblyStateCreateInfo{
		topology = vk.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
		primitiveRestartEnable = vk.VK_FALSE,
	}

	local viewportState = makeVkPipelineViewportStateCreateInfo{
		viewportCount = 1,
		scissorCount = 1,
	}

	local rasterizer = makeVkPipelineRasterizationStateCreateInfo{
		depthClampEnable = vk.VK_FALSE,
		rasterizerDiscardEnable = vk.VK_FALSE,
		polygonMode = vk.VK_POLYGON_MODE_FILL,
		--cullMode = vk::CullModeFlagBits::eBack,
		--frontFace = vk::FrontFace::eClockwise,
		--frontFace = vk::FrontFace::eCounterClockwise,
		depthBiasEnable = vk.VK_FALSE,
		lineWidth = 1,
	}

	local multisampling = makeVkPipelineMultisampleStateCreateInfo{
		rasterizationSamples = msaaSamples,
		sampleShadingEnable = vk.VK_FALSE,
	}

	local depthStencil = makeVkPipelineDepthStencilStateCreateInfo{
		depthTestEnable = vk.VK_TRUE,
		depthWriteEnable = vk.VK_TRUE,
		depthCompareOp = vk.VK_COMPARE_OP_LESS,
		depthBoundsTestEnable = vk.VK_FALSE,
		stencilTestEnable = vk.VK_FALSE,
	}

	local colorBlendAttachment = VkPipelineColorBlendAttachmentState()
	colorBlendAttachment.blendEnable = vk.VK_FALSE
	colorBlendAttachment.colorWriteMask = bit.bor(
		vk.VK_COLOR_COMPONENT_R_BIT,
		vk.VK_COLOR_COMPONENT_G_BIT,
		vk.VK_COLOR_COMPONENT_B_BIT,
		vk.VK_COLOR_COMPONENT_A_BIT
	)

	local colorBlending = makeVkPipelineColorBlendStateCreateInfo{
		logicOpEnable = vk.VK_FALSE,
		logicOp = vk.VK_LOGIC_OP_COPY,
		attachmentCount = 1,
		pAttachments = colorBlendAttachment,
		blendConstants = {0,0,0,0},
	}

	local numDynamicStates = 2
	local dynamicStates = VkDynamicState_array(numDynamicStates)
	dynamicStates[0] = vk.VK_DYNAMIC_STATE_VIEWPORT
	dynamicStates[1] = vk.VK_DYNAMIC_STATE_SCISSOR
	local dynamicState = makeVkPipelineDynamicStateCreateInfo{
		dynamicStateCount = numDynamicStates,
		pDynamicStates = dynamicStates,
	}

	local descriptorSetLayouts = VkDescriptorSetLayout_1(self.descriptorSetLayout.id)

	self.pipelineLayout = VKPipelineLayout{
		device = device,
		setLayoutCount = 1,
		pSetLayouts = descriptorSetLayouts,
	}

	self.vertexShaderModule = VKShaderModule{
		device = device,
		filename = "shader-vert.spv",
	}
	self.fragmentShaderModule = VKShaderModule{
		device = device,
		filename = "shader-frag.spv",
	}
	local numShaderStages = 2
	local shaderStages = VkPipelineShaderStageCreateInfo_array(numShaderStages, {
		makeVkPipelineShaderStageCreateInfo{
			stage = vk.VK_SHADER_STAGE_VERTEX_BIT,
			module = self.vertexShaderModule.id,
			pName = defs.main,	--'vert'	--GLSL uses 'main', but clspv doesn't allow 'main', so ...
		},
		makeVkPipelineShaderStageCreateInfo{
			stage = vk.VK_SHADER_STAGE_FRAGMENT_BIT,
			module = self.fragmentShaderModule.id,
			pName = defs.main,	--'frag'
		},
	})

	--info.basePipelineHandle = {}
	self.obj = VKPipeline{
		device = device,
		stageCount = numShaderStages,
		pStages = shaderStages,
		pVertexInputState = vertexInputInfo,
		pInputAssemblyState = inputAssembly,
		pViewportState = viewportState,
		pRasterizationState = rasterizer,
		pMultisampleState = multisampling,
		pDepthStencilState = depthStencil,
		pColorBlendState = colorBlending,
		pDynamicState = dynamicState,
		layout = self.pipelineLayout.id,
		renderPass = renderPass,
		subpass = 0,
	}
end

function VulkanGraphicsPipeline:destroy()
	if self.descriptorSetLayout then
		self.descriptorSetLayout:destroy()
	end
	if self.pipelineLayout then
		self.pipelineLayout:destroy()
	end
	if self.vertexShaderModule then
		self.vertexShaderModule:destroy()
	end
	if self.fragmentShaderModule then
		self.fragmentShaderModule:destroy()
	end
	if self.obj then
		self.obj:destroy()
	end
	self.descriptorSetLayout = nil
	self.pipelineLayout = nil
	self.vertexShaderModule = nil
	self.fragmentShaderModule = nil
	self.obj = nil
end

return VulkanGraphicsPipeline 
