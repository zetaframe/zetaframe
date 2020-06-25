const std = @import("std");
const Allocator = std.mem.Allocator;

const vk = @import("../include/vk.zig");
const VK_SUCCESS = vk.Result.SUCCESS;

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const Gpu = @import("gpu.zig").Gpu;
const Swapchain = @import("swapchain.zig").Swapchain;
const RenderPass = @import("renderpass.zig").RenderPass;

pub const Framebuffer = struct {
    const Self = @This();

    framebuffer: vk.Framebuffer,

    gpu: *Gpu,

    pub fn init(gpu: *Gpu, attachments: []vk.ImageView, renderPass: *RenderPass, swapchain: *Swapchain) !Self {
        const framebufferInfo = vk.FramebufferCreateInfo{
            .renderPass = renderPass.render_pass,

            .attachmentCount = @intCast(u32, attachments.len),
            .pAttachments = attachments.ptr,

            .width = @intCast(u32, swapchain.extent.width),
            .height = @intCast(u32, swapchain.extent.height),

            .layers = 1,
        };

        const framebuffer = try vk.CreateFramebuffer(gpu.device, framebufferInfo, null);

        return Self{
            .framebuffer = framebuffer,

            .gpu = gpu,
        };
    }
    
    pub fn deinit(self: Self) void {
        vk.DestroyFramebuffer(self.gpu.device, self.framebuffer, null);
    }
};

// pub const Framebuffers = struct {
//     const Self = @This();
//     allocator: *Allocator,

//     framebuffers: []vk.Framebuffer,

//     gpu: *Gpu,

//     pub fn init(allocator: *Allocator, gpu: *Gpu, swapchain: *Swapchain, renderPass: *RenderPass) !Self {
//         var framebuffers = try allocator.alloc(vk.Framebuffer, swapchain.imageviews.len);

//         for (swapchain.imageviews) |imageview, i| {
//             const attachments = [_]vk.ImageView{imageview};

//             const framebufferInfo = vk.FramebufferCreateInfo{
//                 .renderPass = renderPass.render_pass,

//                 .attachmentCount = attachments.len,
//                 .pAttachments = &attachments,

//                 .width = @intCast(u32, swapchain.extent.width),
//                 .height = @intCast(u32, swapchain.extent.height),

//                 .layers = 1,
//             };

//             framebuffers[i] = try vk.CreateFramebuffer(gpu.device, framebufferInfo, null);
//         }

//         return Self{
//             .allocator = allocator,

//             .framebuffers = framebuffers,

//             .gpu = gpu,
//         };
//     }

//     pub fn deinit(self: Self) void {
//         for (self.framebuffers) |framebuffer| {
//             vk.DestroyFramebuffer(self.gpu.device, framebuffer, null);
//         }

//         self.allocator.free(self.framebuffers);
//     }
// };