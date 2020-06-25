const std = @import("std");
const Allocator = std.mem.Allocator;

const windowing = @import("../windowing.zig");

const shader = @import("shader.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const Swapchain = @import("swapchain.zig").Swapchain;

const vk = @import("../include/vk.zig");
const VK_SUCCESS = vk.Result.SUCCESS;

const vma = @import("../include/vma.zig");

const Gpu = @import("gpu.zig").Gpu;
const Buffer = @import("buffer.zig").Buffer;
const Framebuffer = @import("framebuffer.zig").Framebuffer;
const RenderPass = @import("renderpass.zig").RenderPass;
const Pipeline = @import("pipeline.zig").Pipeline;

pub const Command = struct {
    const Self = @This();
    allocator: *Allocator,

    gpu: *Gpu,

    render_pass: *RenderPass,
    pipeline: *Pipeline,
    framebuffers: []Framebuffer,

    vertex_buffer: *Buffer,
    index_buffer: *Buffer,

    command_buffers: []vk.CommandBuffer,

    pub fn new(vertexBuffer: *Buffer, indexBuffer: *Buffer) Self {
        return Self{
            .allocator = undefined,

            .gpu = undefined,

            .render_pass = undefined,
            .pipeline = undefined,
            .framebuffers = undefined,

            .vertex_buffer = vertexBuffer,
            .index_buffer = indexBuffer,

            .command_buffers = undefined,
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, vallocator: *vma.VmaAllocator, gpu: *Gpu, renderPass: *RenderPass, pipeline: *Pipeline, extent: vk.Extent2D, framebuffers: []Framebuffer) !void {
        self.allocator = allocator;

        self.gpu = gpu;

        self.render_pass = renderPass;
        self.pipeline = pipeline;
        self.framebuffers = framebuffers;

        try self.vertex_buffer.init(self.allocator, vallocator, self.gpu);
        try self.index_buffer.init(self.allocator, vallocator, self.gpu);

        try self.createCommandBuffers(renderPass, pipeline, extent, framebuffers);
    }

    pub fn deinit(self: Self) void {
        vk.DeviceWaitIdle(self.gpu.device) catch unreachable;
        
        vk.FreeCommandBuffers(self.gpu.device, self.gpu.graphics_pool, self.command_buffers);
        self.allocator.free(self.command_buffers);

        self.index_buffer.deinit();
        self.vertex_buffer.deinit();
    }

    fn createCommandBuffers(self: *Self, renderPass: *RenderPass, pipeline: *Pipeline, extent: vk.Extent2D, framebuffers: []Framebuffer) !void {
        self.command_buffers = try self.allocator.alloc(vk.CommandBuffer, framebuffers.len);

        const allocInfo = vk.CommandBufferAllocateInfo{
            .commandPool = self.gpu.graphics_pool,

            .level = .PRIMARY,

            .commandBufferCount = @intCast(u32, self.command_buffers.len),
        };

        try vk.AllocateCommandBuffers(self.gpu.device, allocInfo, self.command_buffers);

        for (self.command_buffers) |buffer, i| {
            const beginInfo = vk.CommandBufferBeginInfo{};

            try vk.BeginCommandBuffer(self.command_buffers[i], beginInfo);

            const clearColors = [_]vk.ClearValue{vk.ClearValue{
                .color = vk.ClearColorValue{
                    .float32 = [_]f32{ 0.0, 0.0, 0.0, 1.0 },
                },
            }};

            const renderPassInfo = vk.RenderPassBeginInfo{
                .renderPass = renderPass.render_pass,

                .framebuffer = framebuffers[i].framebuffer,

                .renderArea = vk.Rect2D{
                    .offset = vk.Offset2D{ .x = 0, .y = 0 },
                    .extent = extent,
                },

                .clearValueCount = 1,
                .pClearValues = &clearColors,

                .pNext = null,
            };

            const viewports = [_]vk.Viewport{vk.Viewport{
                .x = 0.0,
                .y = 0.0,
                .width = @intToFloat(f32, extent.width),
                .height = @intToFloat(f32, extent.height),
                .minDepth = 0.0,
                .maxDepth = 1.0,
            }};
            vk.CmdSetViewport(self.command_buffers[i], 0, &viewports);

            const scissors = [_]vk.Rect2D{vk.Rect2D{
                .offset = vk.Offset2D{ .x = 0, .y = 0 },
                .extent = extent,
            }};
            vk.CmdSetScissor(self.command_buffers[i], 0, &scissors);

            vk.CmdBeginRenderPass(self.command_buffers[i], renderPassInfo, .INLINE);
            {
                vk.CmdBindPipeline(self.command_buffers[i], .GRAPHICS, pipeline.pipeline);

                const vertexBuffers = [_]vk.Buffer{self.vertex_buffer.buffer()};
                const offsets = [_]u64{0};

                vk.CmdBindVertexBuffers(self.command_buffers[i], 0, &vertexBuffers, &offsets);
                vk.CmdBindIndexBuffer(self.command_buffers[i], self.index_buffer.buffer(), 0, .UINT16);

                vk.CmdDrawIndexed(self.command_buffers[i], self.index_buffer.len(), 1, 0, 0, 0);
            }
            vk.CmdEndRenderPass(self.command_buffers[i]);

            try vk.EndCommandBuffer(self.command_buffers[i]);
        }
    }
};
