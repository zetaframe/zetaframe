// Re-exports
pub const Context = @import("context.zig").Context;
pub const Swapchain = @import("swapchain.zig").Swapchain;
pub const buffer = @import("buffer.zig");
pub const Program = @import("../program/program.zig").Program;
pub const Uniform = @import("uniform.zig").Uniform;
pub const Framebuffer = @import("framebuffer.zig").Framebuffer;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const vk = @import("../include/vk.zig");
const zva = @import("zva");

const windowing = @import("../windowing.zig");

const ImageView = vk.ImageView;

pub const BackendError = error{
    NoValidDevices,
    ValidationLayersNotAvailable,
    CreateSurfaceFailed,
    AcquireImageFailed,
    PresentFailed,
    InvalidShader,
    UnknownResourceType
};

// Vulkan Backend
pub const Backend = struct {
    pub const Settings = struct {
        in_flight_frames: u8,
    };

    const Self = @This();

    settings: Settings,

    allocator: *Allocator,
    vallocator: zva.Allocator,

    window: *windowing.Window,

    swapchain: Swapchain,

    context: Context,

    present_queue: vk.Queue,
    graphics_queue: vk.Queue,

    frames: []Frame,
    frame_index: u32 = 0,

    pub fn new(allocator: *Allocator, window: *windowing.Window, swapchain: Swapchain, settings: Settings) Self {
        return Self{
            .settings = settings,

            .allocator = allocator,
            .vallocator = undefined,

            .window = window,

            .swapchain = swapchain,

            .context = undefined,

            .present_queue = undefined,
            .graphics_queue = undefined,

            .frames = undefined,
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

        try self.swapchain.init(self.allocator, &self.context, self.window);

        self.frames = try self.allocator.alloc(Frame, self.settings.in_flight_frames);
        for (self.frames) |*frame| {
            frame.* = try Frame.init(&self.context);
        }
    }

    pub fn deinit(self: *Self) void {
        self.context.vkd.deviceWaitIdle(self.context.device) catch unreachable;

        self.swapchain.deinit();

        self.vallocator.deinit();

        self.context.deinit();
    }

    pub fn deinitFrames(self: *Self) void {
        for (self.frames) |*frame| {
            frame.waitForFence() catch unreachable;
            frame.deinit();
        }
        self.allocator.free(self.frames);
    }

    fn recreateSwapchain(self: *Self) !void {
        try self.context.vkd.deviceWaitIdle(self.context.device);

        try self.swapchain.recreate();

        for (self.frames) |*frame| {
            frame.deinit();
        }
        for (self.frames) |*frame| {
            frame.* = try Frame.init(&self.context);
        }
    }

    pub fn present(self: *Self, program: *const Program) !void {
        var currentFrame = &self.frames[self.frame_index];
        try currentFrame.waitForFence();
        try self.context.vkd.resetFences(self.context.device, 1, @ptrCast([*]const vk.Fence, &currentFrame.fence));

        var imageIndex: u32 = 0;
        if (try self.swapchain.acquireNextImage(currentFrame.image_available, &imageIndex)) {
            try self.recreateSwapchain();
            return;
        }

        try currentFrame.prepare(program, &self.swapchain, imageIndex);

        try self.context.vkd.queueSubmit(self.context.graphics_queue, 1, &[_]vk.SubmitInfo{.{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast([*]const vk.Semaphore, &currentFrame.image_available),
            .p_wait_dst_stage_mask = &[_]vk.PipelineStageFlags{.{ .color_attachment_output_bit = true }},

            .command_buffer_count = 1,
            .p_command_buffers = &[_]vk.CommandBuffer{currentFrame.command_buffer},

            .signal_semaphore_count = 1,
            .p_signal_semaphores = @ptrCast([*]const vk.Semaphore, &currentFrame.render_finished),
        }}, currentFrame.fence);

        if (try self.swapchain.present(currentFrame.render_finished, imageIndex)) {
            try self.recreateSwapchain();
            return;
        }

        self.frame_index = (self.frame_index + 1) % self.settings.in_flight_frames;
    }
};

const Frame = struct {
    context: *const Context,

    command_buffer: vk.CommandBuffer,
    framebuffer: ?Framebuffer,

    image_available: vk.Semaphore,
    render_finished: vk.Semaphore,

    fence: vk.Fence,

    fn init(context: *const Context) !Frame {
        var commandBuffer: vk.CommandBuffer = undefined;
        try context.vkd.allocateCommandBuffers(context.device, .{
            .command_pool = context.graphics_pool,

            .level = .primary,

            .command_buffer_count = 1,
        }, @ptrCast([*]vk.CommandBuffer, &commandBuffer));
        errdefer context.vkd.freeCommandBuffers(context.device, context.graphics_pool, 1, @ptrCast([*]vk.CommandBuffer, &commandBuffer));

        const imageAvailable = try context.vkd.createSemaphore(context.device, .{ .flags = .{} }, null);
        errdefer context.vkd.destroySemaphore(context.device, imageAvailable, null);

        const renderFinished = try context.vkd.createSemaphore(context.device, .{ .flags = .{} }, null);
        errdefer context.vkd.destroySemaphore(context.device, renderFinished, null);

        const fence = try context.vkd.createFence(context.device, .{ .flags = .{ .signaled_bit = true } }, null);
        errdefer context.vkd.destroyFence(context.device, fence, null);

        return Frame{
            .context = context,

            .command_buffer = commandBuffer,
            .framebuffer = null,

            .image_available = imageAvailable,
            .render_finished = renderFinished,

            .fence = fence,
        };
    }

    fn deinit(self: Frame) void {
        self.context.vkd.destroyFence(self.context.device, self.fence, null);
        self.context.vkd.destroySemaphore(self.context.device, self.render_finished, null);
        self.context.vkd.destroySemaphore(self.context.device, self.image_available, null);

        if (self.framebuffer) |fb| fb.deinit();

        self.context.vkd.freeCommandBuffers(self.context.device, self.context.graphics_pool, 1, @ptrCast([*]const vk.CommandBuffer, &self.command_buffer));
    }

    fn prepare(self: *Frame, program: *const Program, swapchain: *Swapchain, imageIndex: u32) !void {
        if (self.framebuffer) |fb| fb.deinit();
        var attachment = [_]vk.ImageView{swapchain.images[imageIndex].view};
        self.framebuffer = try Framebuffer.init(self.context, attachment[0..], program.steps[0].RenderPass.renderpass(), swapchain);

        try program.execute(self.command_buffer, self.framebuffer.?);
    }

    fn waitForFence(self: *Frame) !void {
        _ = try self.context.vkd.waitForFences(self.context.device, 1, @ptrCast([*]const vk.Fence, &self.fence), vk.TRUE, std.math.maxInt(u64));
    }
};