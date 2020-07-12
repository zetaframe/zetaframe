const std = @import("std");
const Allocator = std.mem.Allocator;

const testing = std.testing;
const panic = std.debug.panic;

const vk = @import("../include/vk.zig");
const glfw = @import("../include/glfw.zig");
const zva = @import("zva");

const windowing = @import("../windowing.zig");
const shader = @import("shader.zig");

// Re-exports
pub const Shader = @import("shader.zig").Shader;
pub const Context = @import("context.zig").Context;
pub const RenderPass = @import("renderpass.zig").RenderPass;
pub const Pipeline = @import("pipeline.zig").Pipeline;
pub const Swapchain = @import("swapchain.zig").Swapchain;
pub const Command = @import("command.zig").Command;
pub const buffer = @import("buffer.zig");
pub const Framebuffer = @import("framebuffer.zig").Framebuffer;
pub const ImageView = vk.ImageView;

const MAX_FRAMES_IN_FLIGHT: u32 = 2;

pub const VulkanError = error{
    NoValidDevices,
    ValidationLayersNotAvailable,
    CreateSurfaceFailed,
    AcquireImageFailed,
    PresentFailed,
};

// Vulkan Backend
pub const Backend = struct {
    const Self = @This();
    allocator: *Allocator,
    vallocator: zva.Allocator,

    window: *windowing.Window,

    swapchain: Swapchain,
    render_pass: RenderPass,

    context: Context,

    present_queue: vk.Queue,
    graphics_queue: vk.Queue,

    acquired_next: vk.Semaphore,
    image_index: u32 = 0,

    /// Create a new vulkan renderer backend with specified render core
    pub fn new(allocator: *Allocator, window: *windowing.Window, swapchain: Swapchain, renderPass: RenderPass) Self {
        return Self{
            .allocator = allocator,
            .vallocator = undefined,

            .window = window,

            .swapchain = swapchain,
            .render_pass = renderPass,

            .context = undefined,

            .present_queue = undefined,
            .graphics_queue = undefined,

            .acquired_next = undefined,
        };
    }

    pub fn init(self: *Self) !void {
        self.context = try Context.init(self.allocator, self.window);

        self.vallocator = zva.Allocator.init(self.allocator, .{
            .getPhysicalDeviceProperties = self.context.vki.vkGetPhysicalDeviceProperties,
            .getPhysicalDeviceMemoryProperties = self.context.vki.vkGetPhysicalDeviceMemoryProperties,

            .allocateMemory = self.context.vkd.vkAllocateMemory,
            .freeMemory = self.context.vkd.vkFreeMemory,
            .mapMemory = self.context.vkd.vkMapMemory,
            .unmapMemory = self.context.vkd.vkUnmapMemory,
        }, self.context.physical_device, self.context.device, 128);

        self.acquired_next = try self.swapchain.init(self.allocator, &self.context, self.window);

        try self.render_pass.init(&self.context, self.swapchain.image_format);
    }

    pub fn deinit(self: *Self) void {
        self.context.vkd.deviceWaitIdle(self.context.device) catch unreachable;

        self.render_pass.deinit();
        
        self.swapchain.deinit();
        self.context.vkd.destroySemaphore(self.context.device, self.acquired_next, null);

        self.vallocator.deinit();

        self.context.deinit();
    }

    fn recreateSwapchain(self: *Self, command: *Command) !void {
        try self.context.vkd.deviceWaitIdle(self.context.device);

        self.context.vkd.destroySemaphore(self.context.device, self.acquired_next, null);
        self.acquired_next = try self.swapchain.recreate();

        self.render_pass.deinit();
        try self.render_pass.init(&self.context, self.swapchain.image_format);

        command.pipeline.deinit();
        try command.pipeline.init(self.allocator, &self.context, &self.render_pass);

        for (command.framebuffers) |*fb, i| {
            fb.deinit();
            fb.* = try Framebuffer.init(&self.context, &[_]ImageView{self.swapchain.images[i].view}, &self.render_pass, &self.swapchain);
        }

        command.deinit();
        try command.init(self.allocator, &self.vallocator, &self.context, &self.render_pass, command.pipeline, self.swapchain.extent, command.framebuffers);
    }

    pub fn submit(self: *Self, command: *Command) !void {
        const currentImage = self.swapchain.images[self.image_index];
        try currentImage.waitForFence();
        try self.context.vkd.resetFences(self.context.device, 1, @ptrCast([*]const vk.Fence, &currentImage.fence));

        try self.context.vkd.queueSubmit(self.context.graphics_queue, 1, &[_]vk.SubmitInfo{.{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast([*]const vk.Semaphore, &currentImage.acquired),
            .p_wait_dst_stage_mask = &[_]vk.PipelineStageFlags{.{ .top_of_pipe_bit = true }},

            .command_buffer_count = 1,
            .p_command_buffers = &[_]vk.CommandBuffer{command.command_buffers[self.image_index]},

            .signal_semaphore_count = 1,
            .p_signal_semaphores = @ptrCast([*]const vk.Semaphore, &currentImage.presented),
        }}, currentImage.fence);

        if (try self.swapchain.present(currentImage.presented, self.image_index)) try self.recreateSwapchain(command);

        if (try self.swapchain.acquireNextImage(self.acquired_next, &self.image_index)) try self.recreateSwapchain(command);

        std.mem.swap(vk.Semaphore, &self.swapchain.images[self.image_index].acquired, &self.acquired_next);
    }
};
