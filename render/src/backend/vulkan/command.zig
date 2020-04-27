const std = @import("std");

const Allocator = std.mem.Allocator;

const windowing = @import("../../windowing.zig");

const backend = @import("../backend.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const Swapchain = @import("swapchain.zig").Swapchain;

const vk = @import("../../include/vk.zig");
const VK_SUCCESS = vk.Result.SUCCESS;

const vma = @import("../../include/vma.zig");

const Gpu = @import("gpu.zig").Gpu;
const Buffer = @import("buffer.zig").Buffer;

pub const Command = struct {
    const Self = @This();
    allocator: *Allocator,
    vallocator: *vma.VmaAllocator,

    gpu: Gpu,
    extent: vk.Extent2D,
    framebuffers: []vk.Framebuffer,
    render_pass: vk.RenderPass,
    pipeline: vk.Pipeline,

    vertex_buffer: *Buffer,

    command_buffers: []vk.CommandBuffer,

    pub fn new(vertexBuffer: *Buffer) Self {
        return Self{
            .allocator = undefined,
            .vallocator = undefined,

            .gpu = undefined,
            .extent = undefined,
            .framebuffers = undefined,
            .render_pass = undefined,
            .pipeline = undefined,

            .vertex_buffer = vertexBuffer,

            .command_buffers = undefined,
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, vallocator: *vma.VmaAllocator, gpu: Gpu, extent: vk.Extent2D, framebuffers: []vk.Framebuffer, renderPass: vk.RenderPass, pipeline: vk.Pipeline) !void {
        self.allocator = allocator;
        self.vallocator = vallocator;

        self.gpu = gpu;
        self.extent = extent;
        self.framebuffers = framebuffers;
        self.render_pass = renderPass;
        self.pipeline = pipeline;

        try self.vertex_buffer.init(self.allocator, self.vallocator, self.gpu);

        try self.createCommandBuffers();
    }

    pub fn deinit(self: Self) void {
        vk.FreeCommandBuffers(self.gpu.device, self.gpu.graphics_pool, self.command_buffers);
        self.allocator.free(self.command_buffers);

        self.vertex_buffer.deinit();
    }

    fn createCommandBuffers(self: *Self) !void {
        self.command_buffers = try self.allocator.alloc(vk.CommandBuffer, self.framebuffers.len);

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
                .renderPass = self.render_pass,

                .framebuffer = self.framebuffers[i],

                .renderArea = vk.Rect2D{
                    .offset = vk.Offset2D{ .x = 0, .y = 0 },
                    .extent = self.extent,
                },

                .clearValueCount = 1,
                .pClearValues = &clearColors,

                .pNext = null,
            };

            const viewports = [_]vk.Viewport{vk.Viewport{
                .x = 0.0,
                .y = 0.0,
                .width = @intToFloat(f32, self.extent.width),
                .height = @intToFloat(f32, self.extent.height),
                .minDepth = 0.0,
                .maxDepth = 1.0,
            }};
            vk.CmdSetViewport(self.command_buffers[i], 0, &viewports);

            const scissors = [_]vk.Rect2D{vk.Rect2D{
                .offset = vk.Offset2D{ .x = 0, .y = 0 },
                .extent = self.extent,
            }};
            vk.CmdSetScissor(self.command_buffers[i], 0, &scissors);

            vk.CmdBeginRenderPass(self.command_buffers[i], renderPassInfo, .INLINE);
            {
                vk.CmdBindPipeline(self.command_buffers[i], .GRAPHICS, self.pipeline);

                const vertexBuffers = [_]vk.Buffer{self.vertex_buffer.buffer()};
                const offsets = [_]u64{0};

                vk.CmdBindVertexBuffers(self.command_buffers[i], 0, &vertexBuffers, &offsets);

                vk.CmdDraw(self.command_buffers[i], self.vertex_buffer.len(), 1, 0, 0);
            }
            vk.CmdEndRenderPass(self.command_buffers[i]);

            try vk.EndCommandBuffer(self.command_buffers[i]);
        }
    }
};