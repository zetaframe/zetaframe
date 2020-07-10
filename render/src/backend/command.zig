const std = @import("std");
const Allocator = std.mem.Allocator;

const windowing = @import("../windowing.zig");

const shader = @import("shader.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const Swapchain = @import("swapchain.zig").Swapchain;

const vk = @import("../include/vk.zig");

const zva = @import("zva");

const Context = @import("context.zig").Context;
const Buffer = @import("buffer.zig").Buffer;
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const RenderPass = @import("renderpass.zig").RenderPass;
const Pipeline = @import("pipeline.zig").Pipeline;

pub const Command = struct {
    const Self = @This();
    allocator: *Allocator,

    context: *Context,

    render_pass: *RenderPass,
    pipeline: *Pipeline,
    framebuffers: []Framebuffer,

    vertex_buffer: *Buffer,
    index_buffer: *Buffer,

    command_buffers: []vk.CommandBuffer,

    pub fn new(vertexBuffer: *Buffer, indexBuffer: *Buffer) Self {
        return Self{
            .allocator = undefined,

            .context = undefined,

            .render_pass = undefined,
            .pipeline = undefined,
            .framebuffers = undefined,

            .vertex_buffer = vertexBuffer,
            .index_buffer = indexBuffer,

            .command_buffers = undefined,
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, vallocator: *zva.Allocator, context: *Context, renderPass: *RenderPass, pipeline: *Pipeline, extent: vk.Extent2D, framebuffers: []Framebuffer) !void {
        self.allocator = allocator;

        self.context = context;

        self.render_pass = renderPass;
        self.pipeline = pipeline;
        self.framebuffers = framebuffers;

        try self.vertex_buffer.init(self.allocator, vallocator, self.context);
        try self.index_buffer.init(self.allocator, vallocator, self.context);

        try self.createCommandBuffers(renderPass, pipeline, extent, framebuffers);
    }

    pub fn deinit(self: Self) void {
        self.context.vkd.deviceWaitIdle(self.context.device) catch unreachable;

        self.context.vkd.freeCommandBuffers(self.context.device, self.context.graphics_pool, @intCast(u32, self.command_buffers.len), self.command_buffers.ptr);
        self.allocator.free(self.command_buffers);

        self.index_buffer.deinit();
        self.vertex_buffer.deinit();
    }

    fn createCommandBuffers(self: *Self, renderPass: *RenderPass, pipeline: *Pipeline, extent: vk.Extent2D, framebuffers: []Framebuffer) !void {
        self.command_buffers = try self.allocator.alloc(vk.CommandBuffer, framebuffers.len);

        const allocInfo = vk.CommandBufferAllocateInfo{
            .command_pool = self.context.graphics_pool,

            .level = .primary,

            .command_buffer_count = @intCast(u32, self.command_buffers.len),
        };

        try self.context.vkd.allocateCommandBuffers(self.context.device, allocInfo, self.command_buffers.ptr);

        for (self.command_buffers) |buffer, i| {
            const beginInfo = vk.CommandBufferBeginInfo{
                .flags = .{},
                .p_inheritance_info = null,
            };

            try self.context.vkd.beginCommandBuffer(self.command_buffers[i], beginInfo);

            const clearColors = [_]vk.ClearValue{vk.ClearValue{
                .color = vk.ClearColorValue{
                    .float_32 = [_]f32{ 0.0, 0.0, 0.0, 1.0 },
                },
            }};

            const renderPassInfo = vk.RenderPassBeginInfo{
                .render_pass = renderPass.render_pass,

                .framebuffer = framebuffers[i].framebuffer,

                .render_area = vk.Rect2D{
                    .offset = vk.Offset2D{ .x = 0, .y = 0 },
                    .extent = extent,
                },

                .clear_value_count = 1,
                .p_clear_values = &clearColors,
            };

            const viewports = [_]vk.Viewport{vk.Viewport{
                .x = 0.0,
                .y = 0.0,
                .width = @intToFloat(f32, extent.width),
                .height = @intToFloat(f32, extent.height),
                .min_depth = 0.0,
                .max_depth = 1.0,
            }};
            self.context.vkd.cmdSetViewport(self.command_buffers[i], 0, viewports.len, &viewports);

            const scissors = [_]vk.Rect2D{vk.Rect2D{
                .offset = vk.Offset2D{ .x = 0, .y = 0 },
                .extent = extent,
            }};
            self.context.vkd.cmdSetScissor(self.command_buffers[i], 0, scissors.len, &scissors);

            self.context.vkd.cmdBeginRenderPass(self.command_buffers[i], renderPassInfo, .@"inline");
            {
                self.context.vkd.cmdBindPipeline(self.command_buffers[i], .graphics, pipeline.pipeline);

                const vertexBuffers = [_]vk.Buffer{self.vertex_buffer.buffer()};
                const offsets = [_]u64{0};

                self.context.vkd.cmdBindVertexBuffers(self.command_buffers[i], 0, vertexBuffers.len, &vertexBuffers, &offsets);
                self.context.vkd.cmdBindIndexBuffer(self.command_buffers[i], self.index_buffer.buffer(), 0, .uint16);

                self.context.vkd.cmdDrawIndexed(self.command_buffers[i], self.index_buffer.len(), 1, 0, 0, 0);
            }
            self.context.vkd.cmdEndRenderPass(self.command_buffers[i]);

            try self.context.vkd.endCommandBuffer(self.command_buffers[i]);
        }
    }
};
