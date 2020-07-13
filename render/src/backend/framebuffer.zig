const std = @import("std");
const Allocator = std.mem.Allocator;

const vk = @import("../include/vk.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const Context = @import("context.zig").Context;
const Swapchain = @import("swapchain.zig").Swapchain;
const RenderPass = @import("renderpass.zig").RenderPass;

pub const Framebuffer = struct {
    const Self = @This();
    context: *const Context,

    framebuffer: vk.Framebuffer,
    size: vk.Extent2D,

    pub fn init(context: *const Context, attachments: []vk.ImageView, renderPass: *RenderPass, swapchain: *Swapchain) !Self {
        const framebufferInfo = vk.FramebufferCreateInfo{
            .render_pass = renderPass.render_pass,

            .attachment_count = @intCast(u32, attachments.len),
            .p_attachments = attachments.ptr,

            .width = swapchain.extent.width,
            .height = swapchain.extent.height,

            .layers = 1,

            .flags = .{},
        };

        const framebuffer = try context.vkd.createFramebuffer(context.device, framebufferInfo, null);

        return Self{
            .context = context,

            .framebuffer = framebuffer,
            .size = vk.Extent2D{ .width = swapchain.extent.width, .height = swapchain.extent.height },
        };
    }

    pub fn deinit(self: Self) void {
        self.context.vkd.destroyFramebuffer(self.context.device, self.framebuffer, null);
    }
};
