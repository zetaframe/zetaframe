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

    framebuffer: vk.Framebuffer,

    context: *Context,

    pub fn init(context: *Context, attachments: []vk.ImageView, renderPass: *RenderPass, swapchain: *Swapchain) !Self {
        const framebufferInfo = vk.FramebufferCreateInfo{
            .render_pass = renderPass.render_pass,

            .attachment_count = @intCast(u32, attachments.len),
            .p_attachments = attachments.ptr,

            .width = @intCast(u32, swapchain.extent.width),
            .height = @intCast(u32, swapchain.extent.height),

            .layers = 1,

            .flags = .{},
        };

        const framebuffer = try context.vkd.createFramebuffer(context.device, framebufferInfo, null);

        return Self{
            .framebuffer = framebuffer,

            .context = context,
        };
    }

    pub fn deinit(self: Self) void {
        self.context.vkd.destroyFramebuffer(self.context.device, self.framebuffer, null);
    }
};
