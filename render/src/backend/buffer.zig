const std = @import("std");
const Allocator = std.mem.Allocator;

const vk = @import("../include/vk.zig");
const VK_SUCCESS = vk.Result.SUCCESS;

const zva = @import("zva");

const windowing = @import("../windowing.zig");

const shader = @import("shader.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const Gpu = @import("gpu.zig").Gpu;

pub const Buffer = struct {
    initFn: fn (self: *Buffer, allocator: *Allocator, vallocator: *zva.Allocator, gpu: *Gpu) anyerror!void,
    deinitFn: fn (self: *Buffer) void,
    bufferFn: fn (self: *Buffer) vk.Buffer,
    lenFn: fn (self: *Buffer) u32,

    pub fn init(self: *Buffer, allocator: *Allocator, vallocator: *zva.Allocator, gpu: *Gpu) !void {
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

pub const Usage = enum {
    Vertex,
    Index,
};

fn getVkUsage(usage: Usage) vk.BufferUsageFlags {
    return switch (usage) {
        .Vertex => vk.BufferUsageFlags{ .vertexBuffer = true },
        .Index => vk.BufferUsageFlags{ .indexBuffer = true },
    };
}

pub fn DirectBuffer(comptime T: type, comptime usage: Usage) type {
    const bUsage = getVkUsage(usage);

    return struct {
        const Self = @This();
        buf: Buffer,

        allocator: *Allocator,
        vallocator: *zva.Allocator,

        gpu: *Gpu,

        buffer: vk.Buffer,
        allocation: zva.Allocation,

        len: u32,
        size: u64,
        data: []T,

        pub fn new(data: []T) Self {
            return Self{
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

        pub fn init(buf: *Buffer, allocator: *Allocator, vallocator: *zva.Allocator, gpu: *Gpu) anyerror!void {
            const self = @fieldParentPtr(Self, "buf", buf);

            self.allocator = allocator;
            self.vallocator = vallocator;

            self.gpu = gpu;

            const queueFamilyIndices = [_]u32{ gpu.indices.graphics_family.?, gpu.indices.transfer_family.? };
            const differentFamilies = gpu.indices.graphics_family.? != gpu.indices.transfer_family.?;

            const bufferInfo = vk.BufferCreateInfo{
                .size = self.size,

                .usage = bUsage,

                .sharingMode = if (differentFamilies) .CONCURRENT else .EXCLUSIVE,
                .queueFamilyIndexCount = if (differentFamilies) 2 else 0,
                .pQueueFamilyIndices = if (differentFamilies) &queueFamilyIndices else undefined,
            };

            self.buffer = try vk.CreateBuffer(self.gpu.device, bufferInfo, null);

            const memRequirements = vk.GetBufferMemoryRequirements(self.gpu.device, self.buffer);
            self.allocation = try self.vallocator.alloc(memRequirements.size, memRequirements.alignment, memRequirements.memoryTypeBits, .CpuToGpu, .Buffer);
            try vk.BindBufferMemory(self.gpu.device, self.buffer, self.allocation.memory, self.allocation.offset);

            std.mem.copy(T, std.mem.bytesAsSlice(T, self.allocation.data), self.data);
        }

        pub fn deinit(buf: *Buffer) void {
            const self = @fieldParentPtr(Self, "buf", buf);
            vk.DestroyBuffer(self.gpu.device, self.buffer, null);
        }

        pub fn update(self: *Self, data: []T) !void {
            std.debug.assert(data.len == self.len);

            std.mem.copy(T, std.mem.bytesAsSlice(T, self.allocation.data), data);
        }

        pub fn buffer(buf: *Buffer) vk.Buffer {
            const self = @fieldParentPtr(Self, "buf", buf);

            return self.buffer;
        }

        pub fn len(buf: *Buffer) u32 {
            const self = @fieldParentPtr(Self, "buf", buf);

            return self.len;
        }
    };
}

pub fn StagedBuffer(comptime T: type, comptime usage: Usage) type {
    const bUsage = getVkUsage(usage);

    return struct {
        const Self = @This();
        buf: Buffer,

        allocator: *Allocator,
        vallocator: *zva.Allocator,

        gpu: *Gpu,

        sbuffer: vk.Buffer,
        sallocation: zva.Allocation,

        dbuffer: vk.Buffer,
        dallocation: zva.Allocation,

        len: u32,
        size: u64,
        data: []T,

        pub fn new(data: []T) Self {
            return Self{
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

        pub fn init(buf: *Buffer, allocator: *Allocator, vallocator: *zva.Allocator, gpu: *Gpu) anyerror!void {
            const self = @fieldParentPtr(Self, "buf", buf);

            self.allocator = allocator;
            self.vallocator = vallocator;

            self.gpu = gpu;

            const sBufferInfo = vk.BufferCreateInfo{
                .size = self.size,

                .usage = vk.BufferUsageFlags{ .transferSrc = true },
                .sharingMode = .EXCLUSIVE,
            };

            self.sbuffer = try vk.CreateBuffer(self.gpu.device, sBufferInfo, null);

            const sMemRequirements = vk.GetBufferMemoryRequirements(self.gpu.device, self.sbuffer);
            self.sallocation = try self.vallocator.alloc(sMemRequirements.size, sMemRequirements.alignment, sMemRequirements.memoryTypeBits, .CpuToGpu, .Buffer);
            try vk.BindBufferMemory(self.gpu.device, self.sbuffer, self.sallocation.memory, self.sallocation.offset);

            std.mem.copy(T, std.mem.bytesAsSlice(T, self.sallocation.data), self.data);

            const queueFamilyIndices = [_]u32{ gpu.indices.graphics_family.?, gpu.indices.transfer_family.? };
            const differentFamilies = gpu.indices.graphics_family.? != gpu.indices.transfer_family.?;

            const dBufferInfo = vk.BufferCreateInfo{
                .size = self.size,

                .usage = (vk.BufferUsageFlags{ .transferDst = true }).with(bUsage),

                .sharingMode = if (differentFamilies) .CONCURRENT else .EXCLUSIVE,
                .queueFamilyIndexCount = if (differentFamilies) 2 else 0,
                .pQueueFamilyIndices = if (differentFamilies) &queueFamilyIndices else undefined,
            };

            self.dbuffer = try vk.CreateBuffer(self.gpu.device, dBufferInfo, null);

            const dMemRequirements = vk.GetBufferMemoryRequirements(self.gpu.device, self.dbuffer);
            self.dallocation = try self.vallocator.alloc(dMemRequirements.size, dMemRequirements.alignment, dMemRequirements.memoryTypeBits, .GpuOnly, .Buffer);
            try vk.BindBufferMemory(self.gpu.device, self.dbuffer, self.dallocation.memory, self.dallocation.offset);

            try self.copyBuffer();

            self.vallocator.free(self.sallocation);
            vk.DestroyBuffer(self.gpu.device, self.sbuffer, null);
        }

        pub fn deinit(buf: *Buffer) void {
            const self = @fieldParentPtr(Self, "buf", buf);
            vk.DestroyBuffer(self.gpu.device, self.dbuffer, null);
        }

        pub fn update(self: *Self, data: []T) !void {
            std.debug.assert(data.len == self.len);

            const sBufferInfo = vk.BufferCreateInfo{
                .size = self.size,

                .usage = vk.BufferUsageFlags{ .transferSrc = true },
                .sharingMode = .EXCLUSIVE,
            };

            self.sbuffer = try vk.CreateBuffer(self.gpu.device, sBufferInfo, null);

            const sMemRequirements = vk.GetBufferMemoryRequirements(self.gpu.device, self.sbuffer);
            self.sallocation = try self.vallocator.alloc(sMemRequirements.size, sMemRequirements.alignment, sMemRequirements.memoryTypeBits, .CpuToGpu, .Buffer);
            try vk.BindBufferMemory(self.gpu.device, self.sbuffer, self.sallocation.memory, self.sallocation.offset);

            std.mem.copy(T, std.mem.bytesAsSlice(T, self.sallocation.data), data);

            try self.copyBuffer();

            self.vallocator.free(self.sallocation);
            vk.DestroyBuffer(self.gpu.device, self.sbuffer, null);
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
                .flags = vk.CommandBufferUsageFlags{ .oneTimeSubmit = true },
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

            try vk.QueueSubmit(self.gpu.transfer_queue, &submitInfos, .Null);
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
