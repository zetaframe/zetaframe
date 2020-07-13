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

pub const CommandBuffer = struct {
    initFn: fn (self: *CommandBuffer, allocator: *Allocator, vallocator: *zva.Allocator, context: *const Context) anyerror!void,
    deinitFn: fn (self: *CommandBuffer) void,
    recordFn: fn (self: *CommandBuffer, buffer: vk.CommandBuffer, framebuffer: Framebuffer) anyerror!void,

    pub fn init(self: *CommandBuffer, allocator: *Allocator, vallocator: *zva.Allocator, context: *const Context) !void {
        try self.initFn(self, allocator, vallocator, context);
    }

    pub fn deinit(self: *CommandBuffer) void {
        self.deinitFn(self);
    }

    pub fn record(self: *CommandBuffer, buffer: vk.CommandBuffer, framebuffer: Framebuffer) !void {
        try self.recordFn(self, buffer, framebuffer);
    }
};

pub const IndexedDrawCommandBuffer = struct {
    const Self = @This();
    command: CommandBuffer,

    context: *const Context,

    pipeline: *Pipeline,
    render_pass: *RenderPass,

    vertex_buffer: *Buffer,
    index_buffer: *Buffer,

    pub fn new(vertexBuffer: *Buffer, indexBuffer: *Buffer, pipeline: *Pipeline, renderPass: *RenderPass) Self {
        return Self{
            .command = .{
                .initFn = init,
                .deinitFn = deinit,
                .recordFn = record,
            },

            .context = undefined,

            .pipeline = pipeline,
            .render_pass = renderPass,

            .vertex_buffer = vertexBuffer,
            .index_buffer = indexBuffer,
        };
    }

    pub fn init(command: *CommandBuffer, allocator: *Allocator, vallocator: *zva.Allocator, context: *const Context) !void {
        const self = @fieldParentPtr(Self, "command", command);
        self.context = context;

        try self.vertex_buffer.init(allocator, vallocator, context);
        try self.index_buffer.init(allocator, vallocator, context);
    }

    pub fn deinit(command: *CommandBuffer) void {
        const self = @fieldParentPtr(Self, "command", command);

        self.index_buffer.deinit();
        self.vertex_buffer.deinit();
    }

    pub fn record(command: *CommandBuffer, buffer: vk.CommandBuffer, framebuffer: Framebuffer) !void {
        const self = @fieldParentPtr(Self, "command", command);

        const clearColor = vk.ClearValue{ .color = .{ .float_32 = [_]f32{ 0.0, 0.0, 0.0, 1.0 } } };

        const renderPassInfo = vk.RenderPassBeginInfo;

        const viewport = vk.Viewport{
            .x = 0.0,
            .y = 0.0,
            .width = @intToFloat(f32, framebuffer.size.width),
            .height = @intToFloat(f32, framebuffer.size.height),
            .min_depth = 0.0,
            .max_depth = 1.0,
        };

        const scissor = vk.Rect2D{
            .offset = vk.Offset2D{ .x = 0, .y = 0 },
            .extent = framebuffer.size,
        };

        try self.context.vkd.beginCommandBuffer(buffer, .{
            .flags = .{},
            .p_inheritance_info = null,
        });

        self.context.vkd.cmdSetViewport(buffer, 0, 1, @ptrCast([*]const vk.Viewport, &viewport));
        self.context.vkd.cmdSetScissor(buffer, 0, 1, @ptrCast([*]const vk.Rect2D, &scissor));

        self.context.vkd.cmdBeginRenderPass(buffer, .{
            .render_pass = self.render_pass.render_pass,

            .framebuffer = framebuffer.framebuffer,

            .render_area = vk.Rect2D{
                .offset = vk.Offset2D{ .x = 0, .y = 0 },
                .extent = framebuffer.size,
            },

            .clear_value_count = 1,
            .p_clear_values = @ptrCast([*]const vk.ClearValue, &clearColor),
        }, .@"inline");
        {
            self.context.vkd.cmdBindPipeline(buffer, .graphics, self.pipeline.pipeline);

            const offset = [_]vk.DeviceSize{0};
            self.context.vkd.cmdBindVertexBuffers(buffer, 0, 1, @ptrCast([*]const vk.Buffer, &self.vertex_buffer.buffer()), &offset);
            self.context.vkd.cmdBindIndexBuffer(buffer, self.index_buffer.buffer(), 0, .uint16);

            self.context.vkd.cmdDrawIndexed(buffer, self.index_buffer.len(), 1, 0, 0, 0);
        }
        self.context.vkd.cmdEndRenderPass(buffer);

        try self.context.vkd.endCommandBuffer(buffer);
    }
};
