const std = @import("std");

const Allocator = std.mem.Allocator;

const vk = @import("../include/vk.zig");
const VK_SUCCESS = vk.Result.SUCCESS;

const vma = @import("../include/vma.zig");

const windowing = @import("../windowing.zig");

const shader = @import("shader.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const Gpu = @import("gpu.zig").Gpu;
const Swapchain = @import("swapchain.zig").Swapchain;
const RenderPass = @import("renderpass.zig").RenderPass;
const Pipeline = @import("pipeline.zig").Pipeline;
const Command = @import("command.zig").Command;

pub const RenderCore = struct {
    const Self = @This();
    allocator: *Allocator,
    vallocator: *vma.VmaAllocator,

    swapchain: Swapchain,
    command: Command,

    framebuffers: []vk.Framebuffer,

    gpu: *Gpu,
    window: *windowing.Window,

    pub fn new(swapchain: Swapchain, command: Command) Self {
        return Self{
            .allocator = undefined,
            .vallocator = undefined,

            .swapchain = swapchain,
            .command = command,

            .framebuffers = undefined,

            .gpu = undefined,
            .window = undefined,
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, vallocator: *vma.VmaAllocator, gpu: *Gpu, window: *windowing.Window, recreate: bool) !void {
        self.allocator = allocator;

        self.gpu = gpu;
        self.window = window;

        try self.swapchain.init(self.allocator, self.gpu, self.window);

        try self.createFramebuffers();

        try self.command.init(self.allocator, vallocator, self.gpu, self.swapchain.extent, self.framebuffers);
    }

    pub fn deinit(self: *Self, recreate: bool) void {
        self.command.deinit();

        for (self.framebuffers) |framebuffer| {
            vk.DestroyFramebuffer(self.gpu.device, framebuffer, null);
        }

        self.render_pass.deinit();
        self.swapchain.deinit();
    }

    fn createFramebuffers(self: *Self) !void {
        self.framebuffers = try self.allocator.alloc(vk.Framebuffer, self.swapchain.imageviews.len);

        for (self.swapchain.imageviews) |imageview, i| {
            const attachments = [_]vk.ImageView{imageview};

            const framebufferInfo = vk.FramebufferCreateInfo{
                .renderPass = self.render_pass.render_pass,

                .attachmentCount = attachments.len,
                .pAttachments = &attachments,

                .width = @intCast(u32, self.swapchain.extent.width),
                .height = @intCast(u32, self.swapchain.extent.height),

                .layers = 1,
            };

            self.framebuffers[i] = try vk.CreateFramebuffer(self.gpu.device, framebufferInfo, null);
        }
    }
};