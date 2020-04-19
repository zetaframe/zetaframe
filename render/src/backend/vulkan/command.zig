const std = @import("std");

const Allocator = std.mem.Allocator;

const windowing = @import("../../windowing.zig");

const backend = @import("../backend.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const Swapchain = @import("swapchain.zig").Swapchain;

const c = @import("../../c2.zig");
const VK_SUCCESS = c.enum_VkResult.VK_SUCCESS;

const Gpu = @import("gpu.zig").Gpu;

pub const Command = struct {
    const Self = @This();
    allocator: *Allocator,

    gpu: Gpu,
    extent: c.VkExtent2D,
    framebuffers: []c.VkFramebuffer,
    render_pass: c.VkRenderPass,
    pipeline: c.VkPipeline,

    command_pool: c.VkCommandPool,
    command_buffers: []c.VkCommandBuffer,

    pub fn new() Self {
        return Self{
            .allocator = undefined,

            .gpu = undefined,
            .extent = undefined,
            .framebuffers = undefined,
            .render_pass = undefined,
            .pipeline = undefined,

            .command_pool = undefined,
            .command_buffers = undefined,
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, gpu: Gpu, extent: c.VkExtent2D, framebuffers: []c.VkFramebuffer, renderPass: c.VkRenderPass, pipeline: c.VkPipeline) !void {
        self.allocator = allocator;

        self.gpu = gpu;
        self.extent = extent;
        self.framebuffers = framebuffers;
        self.render_pass = renderPass;
        self.pipeline = pipeline;

        try self.createCommandPool();
        try self.createCommandBuffers();
    }

    pub fn deinit(self: Self) void {
        c.vkFreeCommandBuffers(self.gpu.device, self.command_pool, @intCast(u32, self.command_buffers.len), self.command_buffers.ptr);
        self.allocator.free(self.command_buffers);

        c.vkDestroyCommandPool(self.gpu.device, self.command_pool, null);
    }

    fn createCommandPool(self: *Self) !void {
        const indices = self.gpu.indices;

        const poolInfo = c.VkCommandPoolCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,

            .queueFamilyIndex = indices.graphics_family.?,

            .pNext = null,
            .flags = 0,
        };

        if (c.vkCreateCommandPool(self.gpu.device, &poolInfo, null, &self.command_pool) != VK_SUCCESS) {
            return VulkanError.CreateCommandPoolFailed;
        }
    }

    fn createCommandBuffers(self: *Self) !void {
        self.command_buffers = try self.allocator.alloc(c.VkCommandBuffer, self.framebuffers.len);

        const allocInfo = c.VkCommandBufferAllocateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,

            .commandPool = self.command_pool,

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
                c.vkCmdDraw(self.command_buffers[i], 3, 1, 0, 0);
            }
            c.vkCmdEndRenderPass(self.command_buffers[i]);

            if (c.vkEndCommandBuffer(self.command_buffers[i]) != VK_SUCCESS) {
                return VulkanError.RecordCommandBufferFailed;
            }
        }
    }
};