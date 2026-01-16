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


local VkPipelineColorBlendAttachmentState = ffi.typeof'VkPipelineColorBlendAttachmentState'
local VkPipelineShaderStageCreateInfo_array = ffi.typeof'VkPipelineShaderStageCreateInfo[?]'
local VkVertexInputBindingDescription_1 = ffi.typeof'VkVertexInputBindingDescription[1]'


local makeVkPipelineVertexInputStateCreateInfo = makeStructCtor(
	'VkPipelineVertexInputStateCreateInfo',
	{
		{
			name = 'vertexBindingDescriptions',
			type = 'VkVertexInputBindingDescription',
		},
		{
			name = 'vertexAttributeDescriptions',
			type = 'VkVertexInputAttributeDescription',
		},
	}
)

local makeVkPipelineInputAssemblyStateCreateInfo = makeStructCtor'VkPipelineInputAssemblyStateCreateInfo'
local makeVkPipelineViewportStateCreateInfo = makeStructCtor'VkPipelineViewportStateCreateInfo'
local makeVkPipelineRasterizationStateCreateInfo = makeStructCtor'VkPipelineRasterizationStateCreateInfo'
local makeVkPipelineMultisampleStateCreateInfo = makeStructCtor'VkPipelineMultisampleStateCreateInfo'
local makeVkPipelineDepthStencilStateCreateInfo = makeStructCtor'VkPipelineDepthStencilStateCreateInfo'
local makeVkPipelineColorBlendStateCreateInfo = makeStructCtor'VkPipelineColorBlendStateCreateInfo'

local makeVkPipelineDynamicStateCreateInfo = makeStructCtor(
	'VkPipelineDynamicStateCreateInfo',
	{
		{
			name = 'dynamicStates',
			type = 'VkDynamicState',
		},
	}
)


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

	self.pipelineLayout = VKPipelineLayout{
		device = device,
		setLayouts = {
			self.descriptorSetLayout,
		},
	}

	self.vertexShaderModule = VKShaderModule{
		device = device,
		filename = "shader-vert.spv",
	}
	self.fragmentShaderModule = VKShaderModule{
		device = device,
		filename = "shader-frag.spv",
	}

	--info.basePipelineHandle = {}
	self.obj = VKPipeline{
		device = device,
		stages = {
			{
				stage = vk.VK_SHADER_STAGE_VERTEX_BIT,
				module = self.vertexShaderModule.id,
				pName = 'main',	--'vert'	--GLSL uses 'main', but clspv doesn't allow 'main', so ...
			},
			{
				stage = vk.VK_SHADER_STAGE_FRAGMENT_BIT,
				module = self.fragmentShaderModule.id,
				pName = 'main',	--'frag'
			},
		},
		pVertexInputState = makeVkPipelineVertexInputStateCreateInfo{
			vertexBindingDescriptions = {
				VulkanVertex:getBindingDescription()
			},
			-- TODO maybe add makeStuctCtor support for vectors?
			vertexAttributeDescriptions = VulkanVertex:getAttributeDescriptions(),
		},
		pInputAssemblyState = makeVkPipelineInputAssemblyStateCreateInfo{
			topology = vk.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
			primitiveRestartEnable = vk.VK_FALSE,
		},
		pViewportState = makeVkPipelineViewportStateCreateInfo{
			viewportCount = 1,
			scissorCount = 1,
		},
		pRasterizationState = makeVkPipelineRasterizationStateCreateInfo{
			depthClampEnable = vk.VK_FALSE,
			rasterizerDiscardEnable = vk.VK_FALSE,
			polygonMode = vk.VK_POLYGON_MODE_FILL,
			--cullMode = vk::CullModeFlagBits::eBack,
			--frontFace = vk::FrontFace::eClockwise,
			--frontFace = vk::FrontFace::eCounterClockwise,
			depthBiasEnable = vk.VK_FALSE,
			lineWidth = 1,
		},
		pMultisampleState = makeVkPipelineMultisampleStateCreateInfo{
			rasterizationSamples = msaaSamples,
			sampleShadingEnable = vk.VK_FALSE,
		},
		pDepthStencilState = makeVkPipelineDepthStencilStateCreateInfo{
			depthTestEnable = vk.VK_TRUE,
			depthWriteEnable = vk.VK_TRUE,
			depthCompareOp = vk.VK_COMPARE_OP_LESS,
			depthBoundsTestEnable = vk.VK_FALSE,
			stencilTestEnable = vk.VK_FALSE,
		},
		pColorBlendState = 	makeVkPipelineColorBlendStateCreateInfo{
			logicOpEnable = vk.VK_FALSE,
			logicOp = vk.VK_LOGIC_OP_COPY,
			attachmentCount = 1,
			pAttachments = 	VkPipelineColorBlendAttachmentState{
				blendEnable = vk.VK_FALSE,
				colorWriteMask = bit.bor(
					vk.VK_COLOR_COMPONENT_R_BIT,
					vk.VK_COLOR_COMPONENT_G_BIT,
					vk.VK_COLOR_COMPONENT_B_BIT,
					vk.VK_COLOR_COMPONENT_A_BIT
				)
			},
			blendConstants = {0,0,0,0},
		},
		pDynamicState = makeVkPipelineDynamicStateCreateInfo{
			dynamicStates = {
				vk.VK_DYNAMIC_STATE_VIEWPORT,
				vk.VK_DYNAMIC_STATE_SCISSOR,
			},
		},
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
