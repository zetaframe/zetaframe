const std = @import("std");
const Allocator = std.mem.Allocator;

const vk = @import("../include/vk.zig");

const zva = @import("zva");

const windowing = @import("../windowing.zig");

const shader = @import("shader.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const Context = @import("context.zig").Context;

pub const Buffer = struct {
    initFn: fn (self: *Buffer, allocator: *Allocator, vallocator: *zva.Allocator, context: *const Context) anyerror!void,
    deinitFn: fn (self: *Buffer) void,
    bufferFn: fn (self: *Buffer) vk.Buffer,
    lenFn: fn (self: *Buffer) u32,

    pub fn init(self: *Buffer, allocator: *Allocator, vallocator: *zva.Allocator, context: *const Context) !void {
        try self.initFn(self, allocator, vallocator, context);
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
        .Vertex => vk.BufferUsageFlags{ .vertex_buffer_bit = true },
        .Index => vk.BufferUsageFlags{ .index_buffer_bit = true },
    };
}

pub fn DirectBuffer(comptime T: type, comptime usage: Usage) type {
    const bUsage = getVkUsage(usage);

    return struct {
        const Self = @This();
        buf: Buffer,

        allocator: *Allocator,
        vallocator: *zva.Allocator,

        context: *const Context,

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

                .context = undefined,

                .buffer = undefined,
                .allocation = undefined,

                .len = @intCast(u32, data.len),
                .size = @sizeOf(T) * data.len,
                .data = data,
            };
        }

        pub fn init(buf: *Buffer, allocator: *Allocator, vallocator: *zva.Allocator, context: *const Context) anyerror!void {
            const self = @fieldParentPtr(Self, "buf", buf);

            self.allocator = allocator;
            self.vallocator = vallocator;

            self.context = context;

            const queueFamilyIndices = [_]u32{ context.indices.graphics_family.?, context.indices.transfer_family.? };
            const differentFamilies = context.indices.graphics_family.? != context.indices.transfer_family.?;

            const bufferInfo = vk.BufferCreateInfo{
                .size = self.size,

                .usage = bUsage,

                .sharingMode = if (differentFamilies) .CONCURRENT else .EXCLUSIVE,
                .queueFamilyIndexCount = if (differentFamilies) 2 else 0,
                .pQueueFamilyIndices = if (differentFamilies) &queueFamilyIndices else undefined,
            };

            self.buffer = try vk.CreateBuffer(self.context.device, bufferInfo, null);

            const memRequirements = vk.GetBufferMemoryRequirements(self.context.device, self.buffer);
            self.allocation = try self.vallocator.alloc(memRequirements.size, memRequirements.alignment, memRequirements.memoryTypeBits, .CpuToGpu, .Buffer);
            try vk.BindBufferMemory(self.context.device, self.buffer, self.allocation.memory, self.allocation.offset);

            std.mem.copy(T, std.mem.bytesAsSlice(T, self.allocation.data), self.data);
        }

        pub fn deinit(buf: *Buffer) void {
            const self = @fieldParentPtr(Self, "buf", buf);
            vk.DestroyBuffer(self.context.device, self.buffer, null);
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

        context: *const Context,

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

                .context = undefined,

                .sbuffer = undefined,
                .sallocation = undefined,

                .dbuffer = undefined,
                .dallocation = undefined,

                .len = @intCast(u32, data.len),
                .size = @sizeOf(T) * data.len,
                .data = data,
            };
        }

        pub fn init(buf: *Buffer, allocator: *Allocator, vallocator: *zva.Allocator, context: *const Context) anyerror!void {
            const self = @fieldParentPtr(Self, "buf", buf);

            self.allocator = allocator;
            self.vallocator = vallocator;

            self.context = context;

            const sBufferInfo = vk.BufferCreateInfo{
                .size = self.size,

                .usage = vk.BufferUsageFlags{ .transfer_src_bit = true },
                .sharing_mode = .exclusive,

                .flags = .{},
                .queue_family_index_count = 0,
                .p_queue_family_indices = undefined,
            };

            self.sbuffer = try context.vkd.createBuffer(self.context.device, sBufferInfo, null);

            const sMemRequirements = context.vkd.getBufferMemoryRequirements(self.context.device, self.sbuffer);
            self.sallocation = try self.vallocator.alloc(sMemRequirements.size, sMemRequirements.alignment, sMemRequirements.memory_type_bits, .CpuToGpu, .Buffer);
            try context.vkd.bindBufferMemory(self.context.device, self.sbuffer, self.sallocation.memory, self.sallocation.offset);

            std.mem.copy(T, std.mem.bytesAsSlice(T, self.sallocation.data), self.data);

            const queueFamilyIndices = [_]u32{ context.indices.graphics_family.?, context.indices.transfer_family.? };
            const differentFamilies = context.indices.graphics_family.? != context.indices.transfer_family.?;

            const dBufferInfo = vk.BufferCreateInfo{
                .size = self.size,

                .usage = (vk.BufferUsageFlags{ .transfer_dst_bit = true }).merge(bUsage),

                .sharing_mode = if (differentFamilies) .concurrent else .exclusive,
                .queue_family_index_count = if (differentFamilies) 2 else 0,
                .p_queue_family_indices = if (differentFamilies) &queueFamilyIndices else undefined,

                .flags = .{},
            };

            self.dbuffer = try context.vkd.createBuffer(self.context.device, dBufferInfo, null);

            const dMemRequirements = context.vkd.getBufferMemoryRequirements(self.context.device, self.dbuffer);
            self.dallocation = try self.vallocator.alloc(dMemRequirements.size, dMemRequirements.alignment, dMemRequirements.memory_type_bits, .GpuOnly, .Buffer);
            try context.vkd.bindBufferMemory(self.context.device, self.dbuffer, self.dallocation.memory, self.dallocation.offset);

            try self.copyBuffer();

            self.vallocator.free(self.sallocation);
            context.vkd.destroyBuffer(self.context.device, self.sbuffer, null);
        }

        pub fn deinit(buf: *Buffer) void {
            const self = @fieldParentPtr(Self, "buf", buf);
            self.context.vkd.destroyBuffer(self.context.device, self.dbuffer, null);
        }

        pub fn update(self: *Self, data: []T) !void {
            std.debug.assert(data.len == self.len);

            const sBufferInfo = vk.BufferCreateInfo{
                .size = self.size,

                .usage = vk.BufferUsageFlags{ .transfer_src_bit = true },
                .sharing_mode = .exclusive,

                .flags = .{},
                .queue_family_index_count = 0,
                .p_queue_family_indices = undefined,
            };

            self.sbuffer = try self.context.vkd.createBuffer(self.context.device, sBufferInfo, null);

            const sMemRequirements = self.context.vkd.getBufferMemoryRequirements(self.context.device, self.sbuffer);
            self.sallocation = try self.vallocator.alloc(sMemRequirements.size, sMemRequirements.alignment, sMemRequirements.memory_type_bits, .CpuToGpu, .Buffer);
            try self.context.vkd.bindBufferMemory(self.context.device, self.sbuffer, self.sallocation.memory, self.sallocation.offset);

            std.mem.copy(T, std.mem.bytesAsSlice(T, self.sallocation.data), data);

            try self.copyBuffer();

            self.vallocator.free(self.sallocation);
            self.context.vkd.destroyBuffer(self.context.device, self.sbuffer, null);
        }

        pub fn copyBuffer(self: *Self) !void {
            const allocInfo = vk.CommandBufferAllocateInfo{
                .level = .primary,

                .command_pool = self.context.transfer_pool,

                .command_buffer_count = 1,
            };

            var commandBuffer: vk.CommandBuffer = undefined;
            try self.context.vkd.allocateCommandBuffers(self.context.device, allocInfo, @ptrCast([*]vk.CommandBuffer, &commandBuffer));

            const beginInfo = vk.CommandBufferBeginInfo{
                .flags = vk.CommandBufferUsageFlags{ .one_time_submit_bit = true },
                .p_inheritance_info = undefined,
            };

            try self.context.vkd.beginCommandBuffer(commandBuffer, beginInfo);

            const copyRegions = [_]vk.BufferCopy{vk.BufferCopy{
                .src_offset = 0,
                .dst_offset = 0,

                .size = self.size,
            }};

            self.context.vkd.cmdCopyBuffer(commandBuffer, self.sbuffer, self.dbuffer, copyRegions.len, &copyRegions);

            try self.context.vkd.endCommandBuffer(commandBuffer);

            const submitInfos = [_]vk.SubmitInfo{vk.SubmitInfo{
                .command_buffer_count = 1,
                .p_command_buffers = &[_]vk.CommandBuffer{commandBuffer},
                
                .wait_semaphore_count = 0,
                .p_wait_semaphores = undefined,

                .signal_semaphore_count = 0,
                .p_signal_semaphores = undefined,

                .p_wait_dst_stage_mask = undefined,
            }};

            try self.context.vkd.queueSubmit(self.context.transfer_queue, submitInfos.len, &submitInfos, .null_handle);
            try self.context.vkd.queueWaitIdle(self.context.transfer_queue);

            self.context.vkd.freeCommandBuffers(self.context.device, self.context.transfer_pool, 1, &[_]vk.CommandBuffer{commandBuffer});
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
