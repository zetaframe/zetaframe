const std = @import("std");

const Allocator = std.mem.Allocator;

const c = @import("../../c2.zig");
const VK_SUCCESS = c.enum_VkResult.VK_SUCCESS;

const windowing = @import("../../windowing.zig");

const backend = @import("../backend.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const Gpu = @import("gpu.zig").Gpu;

pub const VAllocation = struct {
    const Self = @This();
    pool: ?*VMemoryPool,

    id: u32,

    device_memory: ?c.VkDeviceMemory,

    offset: c.VkDeviceSize,
    size: c.VkDeviceSize,

    data: *[]u8,
};

pub const VAllocationType = enum {
    ALLOCATION_TYPE_FREE,
    ALLOCATION_TYPE_BUFFER,
    ALLOCATION_TYPE_IMAGE,
    ALLOCATION_TYPE_IMAGE_LINEAR,
    ALLOCATION_TYPE_IMAGE_OPTIMAL,
};

pub const VMemoryUsage = enum {
    MEMORY_USAGE_UNKNOWN,
    MEMORY_USAGE_GPU_ONLY,
    MEMORY_USAGE_CPU_ONLY,
    MEMORY_USAGE_CPU_TO_GPU,
    MEMORY_USAGE_GPU_TO_CPU,
};

pub const VAllocator = struct {
    const Self = @This();

    pub fn new() Self {
        return Self{};
    }

    pub fn init(self: *Self) !void {}

    pub fn deinit(self: Self) void {}
};

pub const VMemoryPool = struct {
    const Self = @This();

    gpu: Gpu,

    const Block = struct {
        id: u32,

        size: c.VkDeviceSize,
        offset: c.VkDeviceSize,

        prev: ?*Block,
        next: ?*Block,

        atype: VAllocationType,
    };

    head: Block,

    next_pool_id: u32,

    usage: VMemoryUsage,

    device_memory: ?c.VkDeviceMemory,

    size: c.VkDeviceSize,
    allocated: c.VkDeviceSize,

    memory_type_index: u32,

    data: *[]u8,

    pub fn new(gpu: Gpu, memoryTypeIndex: u32, size: c.VkDeviceSize, usage: VMemoryUsage) Self {
        return Self{
            .gpu = gpu,

            .head = undefined,

            .next_pool_id = 0,

            .usage = usage,

            .device_memory = null,

            .size = size,
            .allocated = 0,

            .memory_type_index = memoryTypeIndex,

            .data = undefined,
        };
    }

    pub fn init() !bool {
        if (self.memory_type_index == std.math.maxInt(u64)) {
            return false;
        }

        const memoryAllocateInfo = c.VkMemoryAllocateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,

            .allocationSize = self.size,

            .memoryTypeIndex = self.memory_type_index,
        };

        if (c.vkAllocateMemory(self.gpu.device, &memoryAllocateInfo, null, &self.device_memory) != VK_SUCCESS) {
            return VulkanError.AllocateMemoryFailed;
        }

        if (self.device_memory == null) {
            return false;
        }

        if (self.usage != .MEMORY_USAGE_GPU_ONLY) {
            if (c.vkMapMemory(self.gpu.device, self.device_memory, 0, self.size, 0, @ptrCast(c_void, self.data)) != VK_SUCCESS) {
                return VulkanError.MapMemoryFailed;
            }
        }

        self.head = Block{
            .id = 0,

            .size = self.size,
            .offset = 0,

            .prev = null,
            .next = null,

            .atype = .ALLOCATION_TYPE_FREE,
        };

        return true;
    }

    pub fn deinit() void {
        if (self.usage != .MEMORY_USAGE_GPU_ONLY) {
            c.vkUnmapMemory(self.gpu.device, self.device_memory);
        }

        c.vkFreeMemory(self.gpu.device, self.device_memory, null);

        self.head = null;
    }

    pub fn alloc(self: *Self, size: u32, alignment: u32, granularity: c.VkDeviceSize, allocType: VAllocationType) ?VAllocation {
        const freeSize: c.VkDeviceSize = self.size - self.allocated;
        if (freeSize < size) {
            return null;
        }

        var curr: ?Block = self.head;
        var best: Block = undefined;
        var prev: Block = undefined;

        var padding: c.VkDeviceSize = 0;
        var offset: c.VkDeviceSize = 0;
        var alignedSize: c.VkDeviceSize = 0;

        while (curr != null) : ({
            prev = curr;
            curr = curr.next;
        }) {
            if (curr.atype != .ALLOCATION_TYPE_FREE) {
                continue;
            }
            if (size > curr.size) {
                continue;
            }

            offset = (((curr.offset) + ((alignment) - 1)) & ~((alignment) - 1));

            if (prev != null and granularity > 1) {
                if (((prev.offset + prev.size - 1) & ~(granularity - 1)) == (offset & ~(granularity - 1))) {
                    const atype = if (@enumToInt(prev.atype) > @enumToInt(allocType)) prev.atype else allocType;

                    switch (atype) {
                        .ALLOCATION_TYPE_BUFFER => {
                            if (allocType == .ALLOCATION_TYPE_IMAGE or allocType == .ALLOCATION_TYPE_IMAGE_OPTIMAL) {
                                offset = (((curr.offset) + ((granularity) - 1)) & ~((granularity) - 1));
                            }
                        },
                        .ALLOCATION_TYPE_IMAGE => {
                            if (allocType == .ALLOCATION_TYPE_IMAGE or allocType == .ALLOCATION_TYPE_IMAGE_LINEAR or allocType == .ALLOCATION_TYPE_IMAGE_OPTIMAL) {
                                offset = (((curr.offset) + ((granularity) - 1)) & ~((granularity) - 1));
                            }
                        },
                        .ALLOCATION_TYPE_IMAGE_LINEAR => {
                            if (allocType == .ALLOCATION_TYPE_IMAGE_OPTIMAL) {
                                offset = (((curr.offset) + ((granularity) - 1)) & ~((granularity) - 1));
                            }
                        },
                        else => {},
                    }
                }
            }

            padding = offset - curr.offset;
            alignedSize = padding + size;

            if (alignedSize > curr.size) {
                continue;
            }
            if (alignedSize + self.allocated >= self.size) {
                return null;
            }

            if (granularity > 1 and curr.next != null) {
                const next = curr.next;
                if (((next.offset + next.size - 1) & ~(granularity - 1)) == (offset & ~(granularity - 1))) {
                    const atype = if (@enumToInt(next.atype) > @enumToInt(allocType)) next.atype else allocType;

                    switch (atype) {
                        .ALLOCATION_TYPE_BUFFER => {
                            if (allocType == .ALLOCATION_TYPE_IMAGE or allocType == .ALLOCATION_TYPE_IMAGE_OPTIMAL) {
                                continue;
                            }
                        },
                        .ALLOCATION_TYPE_IMAGE => {
                            if (allocType == .ALLOCATION_TYPE_IMAGE or allocType == .ALLOCATION_TYPE_IMAGE_LINEAR or allocType == .ALLOCATION_TYPE_IMAGE_OPTIMAL) {
                                continue;
                            }
                        },
                        .ALLOCATION_TYPE_IMAGE_LINEAR => {
                            if (allocType == .ALLOCATION_TYPE_IMAGE_OPTIMAL) {
                                continue;
                            }
                        },
                        else => {},
                    }
                }
            }

            best = curr;
            break;
        }

        if (best.size > size) {
            const next = best.next;

            const chunk = Block{
                .id = self.next_pool_id,

                .size = best.size - alignedSize,
                .offset = offset + size,

                .prev = best,
                .next = next,

                .atype = .ALLOCATION_TYPE_FREE,
            };

            self.next_pool_id += 1;

            if (next != null) {
                nest.prev = &chunk;
            }
        }

        best.atype = allocType;
        best.size = size;

        self.allocated += alignedSize;

        var allocation = VAllocation{
            .pool = self,

            .id = best.id,

            .device_memory = self.device_memory,

            .size = size,
            .offset = offset,

            .data = undefined,
        };

        if (self.usage != .MEMORY_USAGE_GPU_ONLY) {
            allocation.data = self.data + offset;
        }

        return allocation;
    }

    pub fn free(allocation: VAllocation) !void {
        var curr: Block = self.head;
        while (curr != null) : (curr = curr.next) {
            if (curr.id == allocation.id) {
                break;
            }
        }

        if (curr == self.head) {
            return VulkanError.FreeUnknownAllocation;
        }
    }
};
