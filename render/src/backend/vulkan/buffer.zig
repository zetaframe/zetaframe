const std = @import("std");

const Allocator = std.mem.Allocator;

const vk = @import("../../include/vk.zig");
const VK_SUCCESS = vk.Result.SUCCESS;

const vma = @import("../../include/vma.zig");

const windowing = @import("../../windowing.zig");

const backend = @import("../backend.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const Gpu = @import("gpu.zig").Gpu;

pub const Buffer = struct {
    initFn: fn(self: *Buffer, allocator: *Allocator, vallocator: *vma.VmaAllocator, gpu: Gpu) anyerror!void,
    deinitFn: fn(self: *Buffer) void,
    bufferFn: fn(self: *Buffer) vk.Buffer,
    lenFn: fn(self: *Buffer) u32,

    pub fn init(self: *Buffer, allocator: *Allocator, vallocator: *vma.VmaAllocator, gpu: Gpu) !void {
        try self.initFn(self, allocator, vallocator, gpu);
    }

    pub fn deinit(self: *Buffer) void {
        self.deinitFn(self);
    }

    pub fn buffer(self: *Buffer) vk.Buffer {
        return self.bufferFn(self);
    }

    pub fn len(self: *Buffer) u32 {
        return self.lenFn(self);
    }
};

pub const Usage = enum{
    Vertex,
    Index,
};

pub fn CpuBuffer(comptime T: type, comptime usage: Usage) type {
    const bUsage = switch (usage) {
        .Vertex => vk.BufferUsageFlags{ .vertexBuffer = true },
        .Index => vk.BufferUsageFlags{ .indexBuffer = true },
    };

    return struct {
        const Self = @This();
        buf: Buffer,

        allocator: *Allocator,
        vallocator: *vma.VmaAllocator,

        gpu: Gpu,

        buffer: vk.Buffer,
        allocation: vma.VmaAllocation,

        len: u32,
        size: u64,
        data: []T,

        pub fn new(data: []T) Self {
            return Self {
                .buf = Buffer{
                    .initFn = init,
                    .deinitFn = deinit,
                    .bufferFn = buffer,
                    .lenFn = len,
                },

                .allocator = undefined,
                .vallocator = undefined,

                .gpu = undefined,

                .buffer = undefined,
                .allocation = undefined,

                .len = @intCast(u32, data.len),
                .size = @sizeOf(T) * data.len,
                .data = data,
            };
        }

        pub fn init(buf: *Buffer, allocator: *Allocator, vallocator: *vma.VmaAllocator, gpu: Gpu) VulkanError!void {
            const self = @fieldParentPtr(Self, "buf", buf);

            self.allocator = allocator;
            self.vallocator = vallocator;

            self.gpu = gpu;

            const bufferInfo = vk.BufferCreateInfo{
                .sType = vk.enum_VkStructureType.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,

                .size = self.size,

                .usage = @intCast(u32, bUsage),
                .sharingMode = .VK_SHARING_MODE_EXCLUSIVE,

                .queueFamilyIndexCount = 0,
                .pQueueFamilyIndices = null,

                .pNext = null,
                .flags = 0,
            };

            const allocInfo = vma.VmaAllocationCreateInfo{
                .usage = vma.enum_VmaMemoryUsage.VMA_MEMORY_USAGE_CPU_TO_GPU,

                .requiredFlags = vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                .preferredFlags = 0,

                .memoryTypeBits = 0,

                .pool = null,

                .pUserData = null,

                .flags = 0,
            };

            if (vma.vmaCreateBuffer(self.vallocator.*, &bufferInfo, &allocInfo, &self.buffer, &self.allocation, null) != VK_SUCCESS) {
                return VulkanError.CreateBufferFailed;
            }

            var mappedData: []T = undefined;
            if(vma.vmaMapMemory(self.vallocator.*, self.allocation, @ptrCast([*c]?*c_void, &mappedData)) != VK_SUCCESS) {
                return VulkanError.MapMemoryFailed;
            }
            std.mem.copy(T, mappedData, self.data);
            vma.vmaUnmapMemory(self.vallocator.*, self.allocation);
        }

        pub fn deinit(buf: *Buffer) void {
            const self = @fieldParentPtr(Self, "buf", buf);
            vma.vmaDestroyBuffer(self.vallocator.*, self.buffer, self.allocation);
        }

        pub fn buffer(buf: *Buffer) vk.VkBuffer {
            const self = @fieldParentPtr(Self, "buf", buf);

            return self.buffer;
        }

        pub fn len(buf: *Buffer) u32 {
            const self = @fieldParentPtr(Self, "buf", buf);

            return self.len;
        }
    };
}

pub fn TransferBuffer(comptime T: type, comptime usage: Usage) type {
    const bUsage = switch (usage) {
        .Vertex => vk.BufferUsageFlags{ .vertexBuffer = true },
        .Index => vk.BufferUsageFlags{ .indexBuffer = true },
    };

    return struct {
        const Self = @This();
        buf: Buffer,

        allocator: *Allocator,
        vallocator: *vma.VmaAllocator,

        gpu: Gpu,

        sbuffer: vk.Buffer,
        sallocation: vma.VmaAllocation,

        dbuffer: vk.Buffer,
        dallocation: vma.VmaAllocation,

        len: u32,
        size: u64,
        data: []T,

        pub fn new(data: []T) Self {
            return Self {
                .buf = Buffer{
                    .initFn = init,
                    .deinitFn = deinit,
                    .bufferFn = buffer,
                    .lenFn = len,
                },

                .allocator = undefined,
                .vallocator = undefined,

                .gpu = undefined,

                .sbuffer = undefined,
                .sallocation = undefined,

                .dbuffer = undefined,
                .dallocation = undefined,

                .len = @intCast(u32, data.len),
                .size = @sizeOf(T) * data.len,
                .data = data,
            };
        }

        pub fn init(buf: *Buffer, allocator: *Allocator, vallocator: *vma.VmaAllocator, gpu: Gpu) anyerror!void {
            const self = @fieldParentPtr(Self, "buf", buf);

            self.allocator = allocator;
            self.vallocator = vallocator;

            self.gpu = gpu;

            const sBufferInfo = vk.BufferCreateInfo{
                .size = self.size,

                .usage = vk.BufferUsageFlags{.transferSrc = true},
                .sharingMode = .EXCLUSIVE,
            };

            const sAllocInfo = vma.VmaAllocationCreateInfo{
                .usage = vma.enum_VmaMemoryUsage.VMA_MEMORY_USAGE_CPU_TO_GPU,

                .requiredFlags = vk.MemoryPropertyFlags{.hostVisible = true, .hostCoherent = true},
                .preferredFlags = undefined,

                .memoryTypeBits = 0,

                .pool = null,

                .pUserData = null,

                .flags = 0,
            };

            if (vma.vmaCreateBuffer(self.vallocator.*, &sBufferInfo, &sAllocInfo, &self.sbuffer, &self.sallocation, null) != VK_SUCCESS) {
                return VulkanError.CreateBufferFailed;
            }

            var mappedData: []T = undefined;
            if(vma.vmaMapMemory(self.vallocator.*, self.sallocation, @ptrCast([*c]?*c_void, &mappedData)) != VK_SUCCESS) {
                return VulkanError.MapMemoryFailed;
            }
            std.mem.copy(T, mappedData, self.data);
            vma.vmaUnmapMemory(self.vallocator.*, self.sallocation);

            const queueFamilyIndices = [_]u32{ gpu.indices.graphics_family.?, gpu.indices.transfer_family.? };
            const differentFamilies = gpu.indices.graphics_family.? != gpu.indices.transfer_family.?;

            const vBufferInfo = vk.BufferCreateInfo{
                .size = self.size,

                .usage = (vk.BufferUsageFlags{.transferDst = true}).with(bUsage),
                
                .sharingMode = if (differentFamilies) .CONCURRENT else .EXCLUSIVE,
                .queueFamilyIndexCount = if (differentFamilies) 2 else 0,
                .pQueueFamilyIndices = if (differentFamilies) &queueFamilyIndices else undefined,
            };

            const vAllocInfo = vma.VmaAllocationCreateInfo{
                .usage = vma.enum_VmaMemoryUsage.VMA_MEMORY_USAGE_GPU_ONLY,

                .requiredFlags = vk.MemoryPropertyFlags{.deviceLocal = true},
                .preferredFlags = undefined,

                .memoryTypeBits = 0,

                .pool = null,

                .pUserData = null,

                .flags = 0,
            };

            if (vma.vmaCreateBuffer(self.vallocator.*, &vBufferInfo, &vAllocInfo, &self.dbuffer, &self.dallocation, null) != VK_SUCCESS) {
                return VulkanError.CreateBufferFailed;
            }

            try self.copyBuffer();

            vma.vmaDestroyBuffer(self.vallocator.*, self.sbuffer, self.sallocation);
        }

        pub fn deinit(buf: *Buffer) void {
            const self = @fieldParentPtr(Self, "buf", buf);
            vma.vmaDestroyBuffer(self.vallocator.*, self.dbuffer, self.dallocation);
        }

        pub fn copyBuffer(self: *Self) !void {
            const allocInfo = vk.CommandBufferAllocateInfo{
                .level = .PRIMARY,

                .commandPool = self.gpu.transfer_pool,

                .commandBufferCount = 1,
            };

            var commandBuffer: vk.CommandBuffer = undefined;
            try vk.AllocateCommandBuffers(self.gpu.device, allocInfo, @ptrCast(*[1]vk.CommandBuffer, &commandBuffer));
            
            const beginInfo = vk.CommandBufferBeginInfo{
                .flags = vk.CommandBufferUsageFlags{.oneTimeSubmit = true},
            };

            try vk.BeginCommandBuffer(commandBuffer, beginInfo);

            const copyRegions = [_]vk.BufferCopy{vk.BufferCopy{
                .srcOffset = 0,
                .dstOffset = 0,

                .size = self.size,
            }};

            vk.CmdCopyBuffer(commandBuffer, self.sbuffer, self.dbuffer, &copyRegions);

            try vk.EndCommandBuffer(commandBuffer);

            const submitInfos = [_]vk.SubmitInfo{vk.SubmitInfo{
                .commandBufferCount = 1,
                .pCommandBuffers = &[_]vk.CommandBuffer{commandBuffer},
            }};

            try vk.QueueSubmit(self.gpu.transfer_queue, &submitInfos, null);
            try vk.QueueWaitIdle(self.gpu.transfer_queue);

            vk.FreeCommandBuffers(self.gpu.device, self.gpu.transfer_pool, &[_]vk.CommandBuffer{commandBuffer});
        }

        pub fn buffer(buf: *Buffer) vk.Buffer {
            const self = @fieldParentPtr(Self, "buf", buf);

            return self.dbuffer;
        }

        pub fn len(buf: *Buffer) u32 {
            const self = @fieldParentPtr(Self, "buf", buf);

            return self.len;
        }
    };
}