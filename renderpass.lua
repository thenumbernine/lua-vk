require 'ext.gc'
local ffi = require 'ffi'
local class = require 'ext.class'
local assert = require 'ext.assert'
local vk = require 'vk'
local vkassert = require 'vk.util'.vkassert
local vkGet = require 'vk.util'.vkGet
local makeStructCtor = require 'vk.util'.makeStructCtor


local VkRenderPass = ffi.typeof'VkRenderPass'

local makeVkSubpassDescription = makeStructCtor(
	'VkSubpassDescription',
	{
		{
			name = 'colorAttachments',
			type = 'VkAttachmentReference',
		},
		{
			-- NOTICE there's no matching Count field for this ...
			-- ... should it always match colorAttachmentCount ?
			name = 'resolveAttachments',
			type = 'VkAttachmentReference',
		},
		{
			notarray = true,	-- because most the time it's an array I'm permuting
			name = 'depthStencilAttachment',
			ptrname = 'pDepthStencilAttachment',
			type = 'VkAttachmentReference',
		},
	},
	true	-- no sType
)


local makeVkRenderPassCreateInfo = makeStructCtor(
	'VkRenderPassCreateInfo',
	{
		{
			name = 'attachments',
			type = 'VkAttachmentDescription',
		},
		{
			name = 'subpasses',
			ptrname = 'pSubpasses',
			countname = 'subpassCount',
			type = 'VkSubpassDescription',
			gen = makeVkSubpassDescription,
		},
		{
			name = 'dependencies',
			ptrname = 'pDependencies',
			countname = 'dependencyCount',
			type = 'VkSubpassDependency',
		},
	}
)

local VKRenderPass = class()

function VKRenderPass:init(args)
	self.device = assert.index(args, 'device')
	args.device = nil

	self.id, self.idptr = vkGet(
		VkRenderPass,
		vkassert,
		vk.vkCreateRenderPass,
		self.device,
		makeVkRenderPassCreateInfo(args),
		nil
	)
end

function VKRenderPass:destroy()
	if self.id then
		vk.vkDestroyRenderPass(self.device, self.id, nil)
	end
	self.id = nil
end

function VKRenderPass:__gc()
	return self:destroy()
end

return VKRenderPass
