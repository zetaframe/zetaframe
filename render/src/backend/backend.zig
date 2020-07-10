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

    image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
    render_finished_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
    in_flight_fences: [MAX_FRAMES_IN_FLIGHT]vk.Fence,
    in_flight_images: []?vk.Fence,
    current_frame: usize = 0,

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

            .image_available_semaphores = undefined,
            .render_finished_semaphores = undefined,
            .in_flight_fences = undefined,
            .in_flight_images = undefined,
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
            .unmapMemory = self.context.vkd.vkUnmapMemory
        }, self.context.physical_device, self.context.device, 128);

        try self.swapchain.init(self.allocator, &self.context, self.window);
        try self.render_pass.init(&self.context, self.swapchain.image_format);

        try self.createSyncObjects();
    }

    pub fn deinit(self: *Self) void {
        self.context.vkd.deviceWaitIdle(self.context.device) catch unreachable;

        self.render_pass.deinit();
        self.swapchain.deinit();

        var i: usize = 0;
        while (i < MAX_FRAMES_IN_FLIGHT) : (i += 1) {
            self.context.vkd.destroySemaphore(self.context.device, self.render_finished_semaphores[i], null);
            self.context.vkd.destroySemaphore(self.context.device, self.image_available_semaphores[i], null);
            self.context.vkd.destroyFence(self.context.device, self.in_flight_fences[i], null);
        }

        self.allocator.free(self.in_flight_images);

        self.vallocator.deinit();

        self.context.deinit();
    }

    fn recreateSwapchain(self: *Self, command: *Command) !void {
        try self.context.vkd.deviceWaitIdle(self.context.device);
        self.swapchain.deinit();

        try self.swapchain.init(self.allocator, &self.context, self.window);

        self.render_pass.deinit();
        try self.render_pass.init(&self.context, self.swapchain.image_format);

        command.pipeline.deinit();
        try command.pipeline.init(self.allocator, &self.context, &self.render_pass);

        for (command.framebuffers) |*fb, i| {
            fb.deinit();
            fb.* = try Framebuffer.init(&self.context, &[_]ImageView{self.swapchain.imageviews[i]}, &self.render_pass, &self.swapchain);
        }

        command.deinit();
        try command.init(self.allocator, &self.vallocator, &self.context, &self.render_pass, command.pipeline, self.swapchain.extent, command.framebuffers);
    }

    pub fn submit(self: *Self, command: *Command) !void {
        _ = try self.context.vkd.waitForFences(self.context.device, 1, @ptrCast(*[1]vk.Fence, &self.in_flight_fences[self.current_frame]), vk.TRUE, std.math.maxInt(u64));

        var imageIndex: u32 = 0;
        if (try self.swapchain.acquireNextImage(self.image_available_semaphores[self.current_frame], &imageIndex)) try self.recreateSwapchain(command);

        if (self.in_flight_images[imageIndex] != null) {
            std.debug.warn("\n{}\n", .{self.in_flight_images[imageIndex].?});
            _ = try self.context.vkd.waitForFences(self.context.device, 1, @ptrCast(*[1]vk.Fence, &self.in_flight_images[imageIndex].?), vk.TRUE, std.math.maxInt(u64));

            self.in_flight_images[imageIndex] = self.in_flight_fences[self.current_frame];
        }

        var waitSemaphores = [_]vk.Semaphore{self.image_available_semaphores[self.current_frame]};
        var waitStages = [_]vk.PipelineStageFlags{vk.PipelineStageFlags{ .color_attachment_output_bit = true }};
        const waitStageMask: [*]align(4) vk.PipelineStageFlags = @alignCast(4, &waitStages);

        const signalSemaphores = [_]vk.Semaphore{self.render_finished_semaphores[self.current_frame]};

        var submitInfos = [_]vk.SubmitInfo{vk.SubmitInfo{
            .wait_semaphore_count = waitSemaphores.len,
            .p_wait_semaphores = &waitSemaphores,
            .p_wait_dst_stage_mask = waitStageMask,

            .command_buffer_count = 1,
            .p_command_buffers = &[_]vk.CommandBuffer{command.command_buffers[imageIndex]},

            .signal_semaphore_count = signalSemaphores.len,
            .p_signal_semaphores = &signalSemaphores,
        }};

        try self.context.vkd.resetFences(self.context.device, 1, &[_]vk.Fence{self.in_flight_fences[self.current_frame]});

        try self.context.vkd.queueSubmit(self.context.graphics_queue, submitInfos.len, &submitInfos, self.in_flight_fences[self.current_frame]);

        if (try self.swapchain.present(self.render_finished_semaphores[self.current_frame], imageIndex)) try self.recreateSwapchain(command);

        self.current_frame = (self.current_frame + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    fn createSyncObjects(self: *Self) !void {
        const semaphoreInfo = vk.SemaphoreCreateInfo{ .flags = .{} };

        const fenceInfo = vk.FenceCreateInfo{
            .flags = vk.FenceCreateFlags{ .signaled_bit = true },
        };

        self.in_flight_images = try self.allocator.alloc(?vk.Fence, self.swapchain.images.len);
        for (self.in_flight_images) |fence, i| {
            self.in_flight_images[i] = null;
        }

        var i: usize = 0;
        while (i < MAX_FRAMES_IN_FLIGHT) : (i += 1) {
            self.image_available_semaphores[i] = try self.context.vkd.createSemaphore(self.context.device, semaphoreInfo, null);
            self.render_finished_semaphores[i] = try self.context.vkd.createSemaphore(self.context.device, semaphoreInfo, null);
            self.in_flight_fences[i] = try self.context.vkd.createFence(self.context.device, fenceInfo, null);
        }
    }
};
