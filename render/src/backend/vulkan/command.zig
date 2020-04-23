const std = @import("std");

const Allocator = std.mem.Allocator;

const windowing = @import("../../windowing.zig");

const backend = @import("../backend.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const Swapchain = @import("swapchain.zig").Swapchain;

const c = @import("../../c2.zig");
const VK_SUCCESS = c.enum_VkResult.VK_SUCCESS;

const vma = @import("../../vma.zig");

const Gpu = @import("gpu.zig").Gpu;
const Buffer = @import("buffer.zig").Buffer;

pub const Command = struct {
    const Self = @This();
    allocator: *Allocator,
    vallocator: *vma.VmaAllocator,

    gpu: Gpu,
    extent: c.VkExtent2D,
    framebuffers: []c.VkFramebuffer,
    render_pass: c.VkRenderPass,
    pipeline: c.VkPipeline,

    vertex_buffer: *Buffer,

    command_buffers: []c.VkCommandBuffer,

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

    pub fn init(self: *Self, allocator: *Allocator, vallocator: *vma.VmaAllocator, gpu: Gpu, extent: c.VkExtent2D, framebuffers: []c.VkFramebuffer, renderPass: c.VkRenderPass, pipeline: c.VkPipeline) !void {
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
        c.vkFreeCommandBuffers(self.gpu.device, self.gpu.graphics_pool, @intCast(u32, self.command_buffers.len), self.command_buffers.ptr);
        self.allocator.free(self.command_buffers);

        self.vertex_buffer.deinit();
    }

    fn createCommandBuffers(self: *Self) !void {
        self.command_buffers = try self.allocator.alloc(c.VkCommandBuffer, self.framebuffers.len);

        const allocInfo = c.VkCommandBufferAllocateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,

            .commandPool = self.gpu.graphics_pool,

            .level = c.enum_VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY,

            .commandBufferCount = @intCast(u32, self.command_buffers.len),

            .pNext = null,
        };

        if (c.vkAllocateCommandBuffers(self.gpu.device, &allocInfo, self.command_buffers.ptr) != VK_SUCCESS) {
            return VulkanError.AllocCommandBuffersFailed;
        }

        for (self.command_buffers) |buffer, i| {
            const beginInfo = c.VkCommandBufferBeginInfo{
                .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,

                .pInheritanceInfo = null,

                .pNext = null,
                .flags = 0,
            };

            if (c.vkBeginCommandBuffer(self.command_buffers[i], &beginInfo) != VK_SUCCESS) {
                return VulkanError.BeginRecordCommandBufferFailed;
            }

            const clearColor = c.VkClearValue{
                .color = c.VkClearColorValue{
                    .float32 = [_]f32{ 0.0, 0.0, 0.0, 1.0 },
                },
            };

            const renderPassInfo = c.VkRenderPassBeginInfo{
                .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,

                .renderPass = self.render_pass,

                .framebuffer = self.framebuffers[i],

                .renderArea = c.VkRect2D{
                    .offset = c.VkOffset2D{ .x = 0, .y = 0 },
                    .extent = self.extent,
                },

                .clearValueCount = 1,
                .pClearValues = &clearColor,

                .pNext = null,
            };

            const viewports = [_]c.VkViewport{c.VkViewport{
                .x = 0.0,
                .y = 0.0,
                .width = @intToFloat(f32, self.extent.width),
                .height = @intToFloat(f32, self.extent.height),
                .minDepth = 0.0,
                .maxDepth = 1.0,
            }};
            c.vkCmdSetViewport(self.command_buffers[i], 0, viewports.len, &viewports);

            const scissors = [_]c.VkRect2D{c.VkRect2D{
                .offset = c.VkOffset2D{ .x = 0, .y = 0 },
                .extent = self.extent,
            }};
            c.vkCmdSetScissor(self.command_buffers[i], 0, scissors.len, &scissors);

            c.vkCmdBeginRenderPass(self.command_buffers[i], &renderPassInfo, c.enum_VkSubpassContents.VK_SUBPASS_CONTENTS_INLINE);
            {
                c.vkCmdBindPipeline(self.command_buffers[i], c.enum_VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS, self.pipeline);

                const vertexBuffers = [_]c.VkBuffer{self.vertex_buffer.buffer()};
                const offsets = [_]u64{0};

                c.vkCmdBindVertexBuffers(self.command_buffers[i], 0, 1, &vertexBuffers, &offsets);

                c.vkCmdDraw(self.command_buffers[i], self.vertex_buffer.len(), 1, 0, 0);
            }
            c.vkCmdEndRenderPass(self.command_buffers[i]);

            if (c.vkEndCommandBuffer(self.command_buffers[i]) != VK_SUCCESS) {
                return VulkanError.RecordCommandBufferFailed;
            }
        }
    }
};