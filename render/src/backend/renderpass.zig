const std = @import("std");

const Allocator = std.mem.Allocator;

const windowing = @import("../windowing.zig");

const shader = @import("shader.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const vk = @import("../include/vk.zig");
const VK_SUCCESS = vk.Result.SUCCESS;

const Gpu = @import("gpu.zig").Gpu;

pub const RenderPass = struct {
    const Self = @This();
    allocator: *Allocator,

    gpu: Gpu,
    swapchain_image_format: vk.Format,

    render_pass: vk.RenderPass,

    pub fn new() Self {
        return Self{
            .allocator = undefined,

            .gpu = undefined,
            .swapchain_image_format = undefined,

            .render_pass = undefined,
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, gpu: Gpu, swapchainImageFormat: vk.Format) !void {
        self.gpu = gpu;
        self.swapchain_image_format = swapchainImageFormat;

        try self.createRenderPass();
    }

    pub fn deinit(self: Self) void {
        vk.DestroyRenderPass(self.gpu.device, self.render_pass, null);
    }

    fn createRenderPass(self: *Self) !void {
        const colorAttachments = [_]vk.AttachmentDescription{vk.AttachmentDescription{
            .format = self.swapchain_image_format,

            .samples = vk.SampleCountFlags{ .t1 = true },

            .loadOp = .CLEAR,
            .storeOp = .STORE,

            .stencilLoadOp = .DONT_CARE,
            .stencilStoreOp = .DONT_CARE,

            .initialLayout = .UNDEFINED,
            .finalLayout = .PRESENT_SRC_KHR,
        }};

        const colorAttachmentRefs = [_]vk.AttachmentReference{vk.AttachmentReference{
            .attachment = 0,

            .layout = .COLOR_ATTACHMENT_OPTIMAL,
        }};

        const subpasses = [_]vk.SubpassDescription{vk.SubpassDescription{
            .pipelineBindPoint = .GRAPHICS,

            .colorAttachmentCount = colorAttachmentRefs.len,
            .pColorAttachments = &colorAttachmentRefs,
        }};

        const dependencies = [_]vk.SubpassDependency{vk.SubpassDependency{
            .srcSubpass = vk.SUBPASS_EXTERNAL,
            .srcStageMask = vk.PipelineStageFlags{.colorAttachmentOutput = true},
            .srcAccessMask = undefined,

            .dstSubpass = 0,
            .dstStageMask = vk.PipelineStageFlags{.colorAttachmentOutput = true},
            .dstAccessMask = vk.AccessFlags{.colorAttachmentWrite = true},
        }};

        const renderPassInfo = vk.RenderPassCreateInfo{
            .attachmentCount = colorAttachments.len,
            .pAttachments = &colorAttachments,

            .subpassCount = subpasses.len,
            .pSubpasses = &subpasses,

            .dependencyCount = dependencies.len,
            .pDependencies = &dependencies,
        };

        self.render_pass = try vk.CreateRenderPass(self.gpu.device, renderPassInfo, null);
    }
};