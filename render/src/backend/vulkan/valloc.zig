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
    pool: *VMemoryPool,

    block_id: u32,

    device_memory: ?c.VkDeviceMemory,

    offset: c.VkDeviceSize,
    size: c.VkDeviceSize,

    data: [*c]align(8) u8,
};

pub const VAllocationType = enum {
    ALLOCATION_TYPE_FREE,
    ALLOCATION_TYPE_BUFFER,
    ALLOCATION_TYPE_IMAGE,
    ALLOCATION_TYPE_IMAGE_LINEAR,
    ALLOCATION_TYPE_IMAGE_OPTIMAL,
};

pub const VMemoryUsage = enum {
    MEMORY_USAGE_GPU_ONLY,
    MEMORY_USAGE_CPU_ONLY,
    MEMORY_USAGE_CPU_TO_GPU,
    MEMORY_USAGE_GPU_TO_CPU,
};

pub const VAllocator = struct {
    const Self = @This();

    gpu: Gpu,

    gpu_only_pool_size_bytes: u64,
    cpu_accessible_pool_size_bytes: u64,

    image_granularity: c.VkDeviceSize,

    pools: [c.VK_MAX_MEMORY_TYPES]VMemoryPool,
    pool_count: usize = 0,

    pub fn init(gpu: Gpu, gpuOnlyPoolSize: u8, cpuAccessiblePoolSize: u8) Self {
        return Self{
            .gpu = gpu,

            .gpu_only_pool_size_bytes = @intCast(u64, gpuOnlyPoolSize) * 1024 * 1024,
            .cpu_accessible_pool_size_bytes = @intCast(u64, cpuAccessiblePoolSize) * 1024 * 1024,

            .image_granularity = gpu.properties.limits.bufferImageGranularity,

            .pools = undefined,
            .pool_count = 0,
        };
    }

    pub fn deinit(self: Self) void {
        for (self.pools) |pool| {
            pool.deinit();
        }
    }
    
    pub fn alloc(self: *Self, size: u64, alignment: u64, memoryTypeBits: u32, usage: VMemoryUsage, allocType: VAllocationType) !VAllocation {
        var requiredFlags: c.VkMemoryPropertyFlags = 0;
        var preferredFlags: c.VkMemoryPropertyFlags = 0;

        switch (usage) {
            .MEMORY_USAGE_GPU_ONLY => {
                preferredFlags |= @intCast(u32, c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
            },
            .MEMORY_USAGE_CPU_ONLY => {
                requiredFlags |= @intCast(u32, c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT) | @intCast(u32, c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
            },
            .MEMORY_USAGE_GPU_TO_CPU => {
                requiredFlags |= @intCast(u32, c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
                preferredFlags |= @intCast(u32, c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT) | @intCast(u32, c.VK_MEMORY_PROPERTY_HOST_CACHED_BIT);
            },
            .MEMORY_USAGE_CPU_TO_GPU => {
                requiredFlags |= @intCast(u32, c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT);
                preferredFlags |= @intCast(u32, c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
            },
        }

        var memoryTypeIndex: u32 = 0;
        var indexFound = false;
        while(memoryTypeIndex < self.gpu.mem_properties.memoryTypeCount) : (memoryTypeIndex += 1) {
            if ((memoryTypeBits >> @intCast(u5, memoryTypeIndex)) & 1 == 0) {
                continue;
            }

            const properties = self.gpu.mem_properties.memoryTypes[memoryTypeIndex].propertyFlags;
            if (properties & requiredFlags != requiredFlags) {
                continue;
            }
            if(properties & preferredFlags != preferredFlags) {
                continue;
            }

            indexFound = true;
            break;
        }

        if (!indexFound) {
            memoryTypeIndex = 0;
            while(memoryTypeIndex < self.gpu.mem_properties.memoryTypeCount) : (memoryTypeIndex += 1) {
                if ((memoryTypeBits >> @intCast(u5, memoryTypeIndex)) & 1 == 0) {
                    continue;
                }

                const properties = self.gpu.mem_properties.memoryTypes[memoryTypeIndex].propertyFlags;
                if (properties & requiredFlags != requiredFlags) {
                    continue;
                }
                if(properties & preferredFlags != preferredFlags) {
                    continue;
                }

                indexFound = true;
                break;
            }
        }

        if (!indexFound) {
            return VulkanError.MemTypeIndexNotFound;
        }

        for (self.pools) |pool, i| {
            if (pool.memory_type_index != memoryTypeIndex) {
                continue;
            }

            var allocation = self.pools[i].alloc(size, alignment, self.image_granularity, allocType);
            if (allocation != null) {
                return allocation.?;
            }
        }

        //Pool not found
        const poolSize = if (usage != .MEMORY_USAGE_GPU_ONLY) self.cpu_accessible_pool_size_bytes else self.gpu_only_pool_size_bytes;

        var pool = VMemoryPool.new(self.pool_count, self.gpu, memoryTypeIndex, poolSize, usage);
        if (try pool.init()) {
            self.pools[self.pool_count] = pool;
            self.pool_count += 1;
        } else {
            return VulkanError.AllocatePoolFailed;
        }

        var allocation = pool.alloc(size, alignment, self.image_granularity, allocType);
        if (allocation != null) {
            return allocation.?;
        } else {
            return VulkanError.AllocateMemoryFailed;
        }
    }

    pub fn free(self: *Self, allocation: VAllocation) void {
        allocation.pool.free(allocation);

        if (allocation.pool.allocated == 0) {
            self.pools[allocation.pool.id] = undefined;
        }
    }
};

const VMemoryPool = struct {
    const Block = struct {
        id: u32,

        size: c.VkDeviceSize,
        offset: c.VkDeviceSize,

        prev: ?*Block,
        next: ?*Block,

        atype: VAllocationType,
    };

    const Self = @This();

    id: usize,

    gpu: Gpu,

    head: Block,

    next_block_id: u32,

    usage: VMemoryUsage,

    device_memory: c.VkDeviceMemory,

    size: c.VkDeviceSize,
    allocated: c.VkDeviceSize,

    memory_type_index: u32,

    data: [*c]align(8) u8,

    pub fn new(id: usize, gpu: Gpu, memoryTypeIndex: u32, size: c.VkDeviceSize, usage: VMemoryUsage) Self {
        return Self{
            .id = id,

            .gpu = gpu,

            .head = undefined,

            .next_block_id = 0,

            .usage = usage,

            .device_memory = undefined,

            .size = size,
            .allocated = 0,

            .memory_type_index = memoryTypeIndex,

            .data = undefined,
        };
    }

    pub fn init(self: *Self) !bool {
        if (self.memory_type_index == std.math.maxInt(u64)) {
            return false;
        }

        const memoryAllocateInfo = c.VkMemoryAllocateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,

            .allocationSize = self.size,

            .memoryTypeIndex = self.memory_type_index,

            .pNext = null,
        };

        if (c.vkAllocateMemory(self.gpu.device, &memoryAllocateInfo, null, &self.device_memory) != VK_SUCCESS) {
            return VulkanError.AllocateMemoryFailed;
        }

        if (self.usage != .MEMORY_USAGE_GPU_ONLY) {
            // if (c.vkMapMemory(self.gpu.device, self.device_memory, 0, self.size, 0, @ptrCast([*c]?*c_void, self.data)) != VK_SUCCESS) {
            //     return VulkanError.MapMemoryFailed;
            // }
        }

        self.head = Block{
            .id = self.next_block_id,

            .size = self.size,
            .offset = 0,

            .prev = null,
            .next = null,

            .atype = .ALLOCATION_TYPE_FREE,
        };

        self.next_block_id += 1;

        return true;
    }

    pub fn deinit() void {
        if (self.usage != .MEMORY_USAGE_GPU_ONLY) {
            c.vkUnmapMemory(self.gpu.device, self.device_memory);
        }

        c.vkFreeMemory(self.gpu.device, self.device_memory, null);

        self.head = null;
    }

    pub fn alloc(self: *Self, size: u64, alignment: u64, granularity: c.VkDeviceSize, allocType: VAllocationType) ?VAllocation {
        const freeSize: c.VkDeviceSize = self.size - self.allocated;
        if (freeSize < size) {
            return null;
        }

        var curr: ?*Block = &self.head;
        var best: *Block = undefined;
        var prev: ?*Block = null;

        var padding: c.VkDeviceSize = 0;
        var offset: c.VkDeviceSize = 0;
        var alignedSize: c.VkDeviceSize = 0;

        while (curr != null) : ({
            prev = curr;
            curr = curr.?.next;
        }) {
            if (curr.?.atype != .ALLOCATION_TYPE_FREE) {
                continue;
            }
            if (size > curr.?.size) {
                continue;
            }

            offset = (((curr.?.offset) + ((alignment) - 1)) & ~((alignment) - 1));

            if (prev != null and granularity > 1) {
                if (((prev.?.offset + prev.?.size - 1) & ~(granularity - 1)) == (offset & ~(granularity - 1))) {
                    const atype = if (@enumToInt(prev.?.atype) > @enumToInt(allocType)) prev.?.atype else allocType;

                    switch (atype) {
                        .ALLOCATION_TYPE_BUFFER => {
                            if (allocType == .ALLOCATION_TYPE_IMAGE or allocType == .ALLOCATION_TYPE_IMAGE_OPTIMAL) {
                                offset = (((curr.?.offset) + ((granularity) - 1)) & ~((granularity) - 1));
                            }
                        },
                        .ALLOCATION_TYPE_IMAGE => {
                            if (allocType == .ALLOCATION_TYPE_IMAGE or allocType == .ALLOCATION_TYPE_IMAGE_LINEAR or allocType == .ALLOCATION_TYPE_IMAGE_OPTIMAL) {
                                offset = (((curr.?.offset) + ((granularity) - 1)) & ~((granularity) - 1));
                            }
                        },
                        .ALLOCATION_TYPE_IMAGE_LINEAR => {
                            if (allocType == .ALLOCATION_TYPE_IMAGE_OPTIMAL) {
                                offset = (((curr.?.offset) + ((granularity) - 1)) & ~((granularity) - 1));
                            }
                        },
                        else => {},
                    }
                }
            }

            padding = offset - curr.?.offset;
            alignedSize = padding + size;

            if (alignedSize > curr.?.size) {
                continue;
            }
            if (alignedSize + self.allocated >= self.size) {
                return null;
            }

            if (granularity > 1 and curr.?.next != null) {
                const next = curr.?.next.?;
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

            best = curr.?;
            break;
        }

        if (best.size > size) {
            const next = best.next;

            var chunk = Block{
                .id = self.next_block_id,

                .size = best.size - alignedSize,
                .offset = offset + size,

                .prev = best,
                .next = next,

                .atype = .ALLOCATION_TYPE_FREE,
            };

            self.next_block_id += 1;

            if (next != null) {
                next.?.prev = &chunk;
            }
        }

        best.atype = allocType;
        best.size = size;

        self.allocated += alignedSize;

        std.debug.warn("\n{}\n", .{self.device_memory.?.*});

        var allocation = VAllocation{
            .pool = self,

            .block_id = best.id,

            .device_memory = self.device_memory,

            .size = size,
            .offset = offset,

            .data = undefined,
        };

        if (self.usage != .MEMORY_USAGE_GPU_ONLY) {
            allocation.data = @alignCast(8, self.data + offset);
        }

        return allocation;
    }

    pub fn free(self: *Self, allocation: VAllocation) void {
        var curr: ?*Block = &self.head;
        while (curr != null) : (curr = curr.?.next) {
            if (curr.?.id == allocation.block_id) {
                break;
            }
        }

        if (curr.? == &self.head or curr == null) {
            return;
        }

        curr.?.atype = .ALLOCATION_TYPE_FREE;

        if (curr.?.prev != null and curr.?.prev.?.atype == .ALLOCATION_TYPE_FREE) {
            var prev = curr.?.prev.?;

            prev.next = curr.?.next;
            if (curr.?.next != null) {
                curr.?.next.?.prev = prev;
            }

            prev.size += curr.?.size;

            curr = prev;
        }
        if (curr.?.next != null and curr.?.next.?.atype == .ALLOCATION_TYPE_FREE) {
            var next = curr.?.next.?;

            if (next.next != null) {
                next.next.?.prev = curr;
            }

            curr.?.next = next.next;

            curr.?.size += next.size;
        }

        self.allocated -= allocation.size;
    }
};