const std = @import("std");

const Allocator = std.mem.Allocator;

const windowing = @import("../../windowing.zig");

const backend = @import("../backend.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const c = @import("../../c2.zig");
const VK_SUCCESS = c.enum_VkResult.VK_SUCCESS;

const Gpu = @import("gpu.zig").Gpu;

pub const RenderPass = struct {
    const Self = @This();
    allocator: *Allocator,

    gpu: Gpu,
    swapchain_image_format: c.VkFormat,

    render_pass: c.VkRenderPass,

    pub fn new() Self {
        return Self{
            .allocator = undefined,

            .gpu = undefined,
            .swapchain_image_format = undefined,

            .render_pass = undefined,
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, gpu: Gpu, swapchainImageFormat: c.VkFormat) !void {
        self.gpu = gpu;
        self.swapchain_image_format = swapchainImageFormat;

        try self.createRenderPass();
    }

    pub fn deinit(self: Self) void {
        c.vkDestroyRenderPass(self.gpu.device, self.render_pass, null);
    }

    fn createRenderPass(self: *Self) !void {
        const colorAttachments = [_]c.VkAttachmentDescription{c.VkAttachmentDescription{
            .format = self.swapchain_image_format,

            .samples = c.enum_VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,

            .loadOp = c.enum_VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
            .storeOp = c.enum_VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,

            .stencilLoadOp = c.enum_VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
            .stencilStoreOp = c.enum_VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,

            .initialLayout = c.enum_VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
            .finalLayout = c.enum_VkImageLayout.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,

            .flags = 0,
        }};

        const colorAttachmentRefs = [_]c.VkAttachmentReference{c.VkAttachmentReference{
            .attachment = 0,

            .layout = c.enum_VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        }};

        const subpasses = [_]c.VkSubpassDescription{c.VkSubpassDescription{
            .pipelineBindPoint = c.enum_VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS,

            .colorAttachmentCount = colorAttachmentRefs.len,
            .pColorAttachments = &colorAttachmentRefs,

            .inputAttachmentCount = 0,
            .pInputAttachments = null,

            .pResolveAttachments = null,

            .pDepthStencilAttachment = null,

            .preserveAttachmentCount = 0,
            .pPreserveAttachments = null,

            .flags = 0,
        }};

        const dependencies = [_]c.VkSubpassDependency{c.VkSubpassDependency{
            .srcSubpass = c.VK_SUBPASS_EXTERNAL,
            .srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            .srcAccessMask = 0,

            .dstSubpass = 0,
            .dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            .dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,

            .dependencyFlags = 0,
        }};

        const renderPassInfo = c.VkRenderPassCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,

            .attachmentCount = colorAttachments.len,
            .pAttachments = &colorAttachments,

            .subpassCount = subpasses.len,
            .pSubpasses = &subpasses,

            .dependencyCount = dependencies.len,
            .pDependencies = &dependencies,

            .pNext = null,
            .flags = 0,
        };

        if (c.vkCreateRenderPass(self.gpu.device, &renderPassInfo, null, &self.render_pass) != VK_SUCCESS) {
            return VulkanError.CreateRenderPassFailed;
        }
    }
};