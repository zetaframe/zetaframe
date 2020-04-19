const std = @import("std");

const Allocator = std.mem.Allocator;
const VAllocator = @import("vallocator.zig").VAllocator;

const c = @import("../../c2.zig");
const VK_SUCCESS = c.enum_VkResult.VK_SUCCESS;

const windowing = @import("../../windowing.zig");

const backend = @import("../backend.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const Gpu = @import("gpu.zig").Gpu;

pub const CpuBuffer = struct {
    const Self = @This();
    allocator: *Allocator,
    vallocator: *VAllocator,

    buffer: c.VkBuffer,

    gpu: Gpu,

    size: u32,

    pub fn new(size: u32) Self {
        return Self{
            .allocator = undefined,
            .vallocator = undefined,

            .buffer = undefined,

            .gpu = undefined,

            .size = size,
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, vallocator: *VAllocator, gpu: Gpu) !void {
        self.gpu = gpu;

        const bufferInfo = c.VkBufferCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,

            .size = self.size,

            .usage = c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
            .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        };

        if(c.vkCreateBuffer(self.gpu.device, &bufferInfo, null, &self.buffer) != VK_SUCCESS) {
            return VulkanError.CreateBufferFailed;
        }

        var memoryRequirements: c.VkMemoryRequirements = undefined;
        c.vkGetBufferMemoryRequirements(self.gpu.device, self.buffer, &memoryRequirements);
        
    }

    pub fn deinit(self: Self) void {
        c.vkDestroyBuffer(self.gpu.device, self.buffer, null);
    }
};