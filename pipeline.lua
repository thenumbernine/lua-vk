require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkPipeline = ffi.typeof'VkPipeline'

local makeVkPipelineShaderStageCreateInfo = makeStructCtor'VkPipelineShaderStageCreateInfo'

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

local makeVkPipelineColorBlendStateCreateInfo = makeStructCtor(
	'VkPipelineColorBlendStateCreateInfo',
	{
		{
			name = 'attachments',
			type = 'VkPipelineColorBlendAttachmentState',
		},
	}
)

local makeVkPipelineDynamicStateCreateInfo = makeStructCtor(
	'VkPipelineDynamicStateCreateInfo',
	{
		{
			name = 'dynamicStates',
			type = 'VkDynamicState',
		},
	}
)

local makeVkGraphicsPipelineCreateInfo = makeStructCtor(
	'VkGraphicsPipelineCreateInfo',
	{
		{
			name = 'stages',
			type = 'VkPipelineShaderStageCreateInfo',
			gen = makeVkPipelineShaderStageCreateInfo,
		},
		{
			name = 'vertexInputState',
			ptrname = 'pVertexInputState',
			gen = makeVkPipelineVertexInputStateCreateInfo,
			notarray = true,
		},
		{
			name = 'inputAssemblyState',
			ptrname = 'pInputAssemblyState',
			gen = makeVkPipelineInputAssemblyStateCreateInfo,
			notarray = true,
		},
		{
			name = 'viewportState',
			ptrname = 'pViewportState',
			gen = makeVkPipelineViewportStateCreateInfo,
			notarray = true,
		},
		{
			name = 'rasterizationState',
			ptrname = 'pRasterizationState',
			gen = makeVkPipelineRasterizationStateCreateInfo,
			notarray = true,
		},
		{
			name = 'multisampleState',
			ptrname = 'pMultisampleState',
			gen = makeVkPipelineMultisampleStateCreateInfo,
			notarray = true,
		},
		{
			name = 'depthStencilState',
			ptrname = 'pDepthStencilState',
			gen = makeVkPipelineDepthStencilStateCreateInfo,
			notarray = true,
		},
		{
			name = 'colorBlendState',
			ptrname = 'pColorBlendState',
			gen = makeVkPipelineColorBlendStateCreateInfo,
			notarray = true,
		},
		{
			name = 'dynamicState',
			ptrname = 'pDynamicState',
			gen = makeVkPipelineDynamicStateCreateInfo,
			notarray = true,
		},
	}
)


local VKPipeline = class()

function VKPipeline:init(args)
	self.device = assert.index(args, 'device')
	args.device = nil

	self.id, self.idptr = vkGet(
		VkPipeline,
		vkassert,
		vk.vkCreateGraphicsPipelines,
		self.device,
		nil,
		1,
		makeVkGraphicsPipelineCreateInfo(args),
		nil
	)
end

function VKPipeline:destroy()
	if self.id then
		vk.vkDestroyPipeline(self.device, self.id, nil)
	end
	self.id = nil
end

function VKPipeline:__gc()
	return self:destroy()
end

return VKPipeline
