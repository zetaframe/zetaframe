const std = @import("std");

const Allocator = std.mem.Allocator;

const c = @import("../../c2.zig");
const VK_SUCCESS = c.enum_VkResult.VK_SUCCESS;

const vma = @import("../../vma.zig");

const windowing = @import("../../windowing.zig");

const backend = @import("../backend.zig");

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
    render_pass: RenderPass,
    pipeline: Pipeline,
    command: Command,

    framebuffers: []c.VkFramebuffer,

    gpu: Gpu,
    window: *windowing.Window,

    pub fn new(swapchain: Swapchain, renderPass: RenderPass, pipeline: Pipeline, command: Command) Self {
        return Self{
            .allocator = undefined,
            .vallocator = undefined,

            .swapchain = swapchain,
            .render_pass = renderPass,
            .pipeline = pipeline,
            .command = command,

            .framebuffers = undefined,

            .gpu = undefined,
            .window = undefined,
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, vallocator: *vma.VmaAllocator, recreate: bool, gpu: Gpu, window: *windowing.Window) !void {
        self.allocator = allocator;

        self.gpu = gpu;
        self.window = window;

        try self.swapchain.init(self.allocator, self.gpu, self.window);
        try self.render_pass.init(self.allocator, self.gpu, self.swapchain.image_format);

        if(!recreate){
            try self.pipeline.init(self.allocator, self.gpu, self.swapchain.extent, self.swapchain.image_format, self.render_pass.render_pass, self.window.size);
        }

        try self.createFramebuffers();

        try self.command.init(self.allocator, vallocator, self.gpu, self.swapchain.extent, self.framebuffers, self.render_pass.render_pass, self.pipeline.pipeline);
    }

    pub fn deinit(self: *Self, recreate: bool) void {
        self.command.deinit();

        for (self.framebuffers) |framebuffer| {
            c.vkDestroyFramebuffer(self.gpu.device, framebuffer, null);
        }

        if (!recreate) {
            self.pipeline.deinit();
        }

        self.render_pass.deinit();
        self.swapchain.deinit();
    }

    fn createFramebuffers(self: *Self) !void {
        self.framebuffers = try self.allocator.alloc(c.VkFramebuffer, self.swapchain.imageviews.len);

        for (self.swapchain.imageviews) |imageview, i| {
            const attachments = [_]c.VkImageView{imageview};

            const framebufferInfo = c.VkFramebufferCreateInfo{
                .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,

                .renderPass = self.render_pass.render_pass,

                .attachmentCount = attachments.len,
                .pAttachments = &attachments,

                .width = @intCast(u32, self.swapchain.extent.width),
                .height = @intCast(u32, self.swapchain.extent.height),

                .layers = 1,

                .pNext = null,
                .flags = 0,
            };

            if (c.vkCreateFramebuffer(self.gpu.device, &framebufferInfo, null, &self.framebuffers[i]) != VK_SUCCESS) {
                return VulkanError.CreateFramebufferFailed;
            }
        }
    }
};