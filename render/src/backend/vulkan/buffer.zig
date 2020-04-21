const std = @import("std");

const Allocator = std.mem.Allocator;

const c = @import("../../c2.zig");
const VK_SUCCESS = c.enum_VkResult.VK_SUCCESS;

const vma = @import("../../vma.zig");

const windowing = @import("../../windowing.zig");

const backend = @import("../backend.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const Gpu = @import("gpu.zig").Gpu;

pub const Buffer = struct {
    initFn: fn(self: *Buffer, allocator: *Allocator, vallocator: *vma.VmaAllocator, gpu: Gpu) VulkanError!void,
    deinitFn: fn(self: *Buffer) void,
    bufferFn: fn(self: *Buffer) c.VkBuffer,
    lenFn: fn(self: *Buffer) u32,

    pub fn init(self: *Buffer, allocator: *Allocator, vallocator: *vma.VmaAllocator, gpu: Gpu) !void {
        try self.initFn(self, allocator, vallocator, gpu);
    }

    pub fn deinit(self: *Buffer) void {
        self.deinitFn(self);
    }

    pub fn buffer(self: *Buffer) c.VkBuffer {
        return self.bufferFn(self);
    }

    pub fn len(self: *Buffer) u32 {
        return self.lenFn(self);
    }
};

pub fn CpuToGpuBuffer(comptime T: type) type {
    return struct {
        const Self = @This();
        buf: Buffer,

        allocator: *Allocator,
        vallocator: *vma.VmaAllocator,

        gpu: Gpu,

        vkbuffer: c.VkBuffer,
        allocation: vma.VmaAllocation,

        len: u32,
        size: u64,
        data: []T,
        usage: c.enum_VkBufferUsageFlagBits,
        sharing_mode: c.enum_VkSharingMode,

        pub fn new(data: []T, usage: c.enum_VkBufferUsageFlagBits, sharingMode: c.enum_VkSharingMode) Self {
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

                .vkbuffer = undefined,
                .allocation = undefined,

                .len = @intCast(u32, data.len),
                .size = @sizeOf(T) * data.len,
                .data = data,
                .usage = usage,
                .sharing_mode = sharingMode,
            };
        }

        pub fn init(buf: *Buffer, allocator: *Allocator, vallocator: *vma.VmaAllocator, gpu: Gpu) VulkanError!void {
            const self = @fieldParentPtr(Self, "buf", buf);

            self.allocator = allocator;
            self.vallocator = vallocator;

            self.gpu = gpu;

            const bufferInfo = c.VkBufferCreateInfo{
                .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,

                .size = self.size,

                .usage = @intCast(u32, @enumToInt(self.usage)),
                .sharingMode = self.sharing_mode,

                .queueFamilyIndexCount = 0,
                .pQueueFamilyIndices = null,

                .pNext = null,
                .flags = 0,
            };

            const allocInfo = vma.VmaAllocationCreateInfo{
                .usage = vma.enum_VmaMemoryUsage.VMA_MEMORY_USAGE_CPU_TO_GPU,

                .requiredFlags = c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                .preferredFlags = c.VK_MEMORY_PROPERTY_HOST_CACHED_BIT,

                .memoryTypeBits = 0,

                .pool = null,

                .pUserData = null,

                .flags = 0,
            };

            if (vma.vmaCreateBuffer(self.vallocator.*, &bufferInfo, &allocInfo, &self.vkbuffer, &self.allocation, null) != VK_SUCCESS) {
                return VulkanError.CreateBufferFailed;
            }

            var mappedData: []T = undefined;
            _ = vma.vmaMapMemory(self.vallocator.*, self.allocation, @ptrCast([*c]?*c_void, &mappedData));
            std.mem.copy(T, mappedData, self.data);
            vma.vmaUnmapMemory(self.vallocator.*, self.allocation);
        }

        pub fn deinit(buf: *Buffer) void {
            const self = @fieldParentPtr(Self, "buf", buf);
            vma.vmaDestroyBuffer(self.vallocator.*, self.vkbuffer, self.allocation);
        }

        pub fn buffer(buf: *Buffer) c.VkBuffer {
            const self = @fieldParentPtr(Self, "buf", buf);

            return self.vkbuffer;
        }

        pub fn len(buf: *Buffer) u32 {
            const self = @fieldParentPtr(Self, "buf", buf);

            return self.len;
        }
    };
}

pub fn GpuBuffer(comptime T: type) type {
    return struct {
        const Self = @This();
        buf: Buffer,

        allocator: *Allocator,
        vallocator: *vma.VmaAllocator,

        gpu: Gpu,

        vkbuffer: c.VkBuffer,
        allocation: vma.VmaAllocation,

        len: u32,
        size: u64,
        data: []T,
        usage: c.enum_VkBufferUsageFlagBits,
        sharing_mode: c.enum_VkSharingMode,

        pub fn new(data: []T, usage: c.enum_VkBufferUsageFlagBits, sharingMode: c.enum_VkSharingMode) Self {
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

                .vkbuffer = undefined,
                .allocation = undefined,

                .len = @intCast(u32, data.len),
                .size = @sizeOf(T) * data.len,
                .data = data,
                .usage = usage,
                .sharing_mode = sharingMode,
            };
        }

        pub fn init(buf: *Buffer, allocator: *Allocator, vallocator: *vma.VmaAllocator, gpu: Gpu) VulkanError!void {
            const self = @fieldParentPtr(Self, "buf", buf);

            self.allocator = allocator;
            self.vallocator = vallocator;

            self.gpu = gpu;

            const bufferInfo = c.VkBufferCreateInfo{
                .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,

                .size = self.size,

                .usage = @intCast(u32, @enumToInt(self.usage)),
                .sharingMode = self.sharing_mode,

                .queueFamilyIndexCount = 0,
                .pQueueFamilyIndices = null,

                .pNext = null,
                .flags = 0,
            };

            const allocInfo = vma.VmaAllocationCreateInfo{
                .usage = vma.enum_VmaMemoryUsage.VMA_MEMORY_USAGE_GPU_ONLY,

                .requiredFlags = c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                .preferredFlags = 0,

                .memoryTypeBits = 0,

                .pool = null,

                .pUserData = null,

                .flags = 0,
            };

            if (vma.vmaCreateBuffer(self.vallocator.*, &bufferInfo, &allocInfo, &self.vkbuffer, &self.allocation, null) != VK_SUCCESS) {
                return VulkanError.CreateBufferFailed;
            }

            var mappedData: []T = undefined;
            _ = vma.vmaMapMemory(self.vallocator.*, self.allocation, @ptrCast([*c]?*c_void, &mappedData));
            std.mem.copy(T, mappedData, self.data);
            vma.vmaUnmapMemory(self.vallocator.*, self.allocation);
        }

        pub fn deinit(buf: *Buffer) void {
            const self = @fieldParentPtr(Self, "buf", buf);
            vma.vmaDestroyBuffer(self.vallocator.*, self.vkbuffer, self.allocation);
        }

        pub fn buffer(buf: *Buffer) c.VkBuffer {
            const self = @fieldParentPtr(Self, "buf", buf);

            return self.vkbuffer;
        }

        pub fn len(buf: *Buffer) u32 {
            const self = @fieldParentPtr(Self, "buf", buf);

            return self.len;
        }
    };
}
