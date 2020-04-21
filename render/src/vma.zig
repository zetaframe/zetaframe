const c = @import("c2.zig");

pub const struct_VmaAllocator_T = @OpaqueType();
pub const VmaAllocator = ?*struct_VmaAllocator_T;
pub const PFN_vmaAllocateDeviceMemoryFunction = ?fn (VmaAllocator, u32, c.VkDeviceMemory, c.VkDeviceSize, ?*c_void) callconv(.C) void;
pub const PFN_vmaFreeDeviceMemoryFunction = ?fn (VmaAllocator, u32, c.VkDeviceMemory, c.VkDeviceSize, ?*c_void) callconv(.C) void;
pub const struct_VmaDeviceMemoryCallbacks = extern struct {
    pfnAllocate: PFN_vmaAllocateDeviceMemoryFunction,
    pfnFree: PFN_vmaFreeDeviceMemoryFunction,
    pUserData: ?*c_void,
};
pub const VmaDeviceMemoryCallbacks = struct_VmaDeviceMemoryCallbacks;
pub const VMA_ALLOCATOR_CREATE_EXTERNALLY_SYNCHRONIZED_BIT = @enumToInt(enum_VmaAllocatorCreateFlagBits.VMA_ALLOCATOR_CREATE_EXTERNALLY_SYNCHRONIZED_BIT);
pub const VMA_ALLOCATOR_CREATE_KHR_DEDICATED_ALLOCATION_BIT = @enumToInt(enum_VmaAllocatorCreateFlagBits.VMA_ALLOCATOR_CREATE_KHR_DEDICATED_ALLOCATION_BIT);
pub const VMA_ALLOCATOR_CREATE_KHR_BIND_MEMORY2_BIT = @enumToInt(enum_VmaAllocatorCreateFlagBits.VMA_ALLOCATOR_CREATE_KHR_BIND_MEMORY2_BIT);
pub const VMA_ALLOCATOR_CREATE_EXT_MEMORY_BUDGET_BIT = @enumToInt(enum_VmaAllocatorCreateFlagBits.VMA_ALLOCATOR_CREATE_EXT_MEMORY_BUDGET_BIT);
pub const VMA_ALLOCATOR_CREATE_AMD_DEVICE_COHERENT_MEMORY_BIT = @enumToInt(enum_VmaAllocatorCreateFlagBits.VMA_ALLOCATOR_CREATE_AMD_DEVICE_COHERENT_MEMORY_BIT);
pub const VMA_ALLOCATOR_CREATE_BUFFER_DEVICE_ADDRESS_BIT = @enumToInt(enum_VmaAllocatorCreateFlagBits.VMA_ALLOCATOR_CREATE_BUFFER_DEVICE_ADDRESS_BIT);
pub const VMA_ALLOCATOR_CREATE_FLAG_BITS_MAX_ENUM = @enumToInt(enum_VmaAllocatorCreateFlagBits.VMA_ALLOCATOR_CREATE_FLAG_BITS_MAX_ENUM);
pub const enum_VmaAllocatorCreateFlagBits = extern enum(c_int) {
    VMA_ALLOCATOR_CREATE_EXTERNALLY_SYNCHRONIZED_BIT = 1,
    VMA_ALLOCATOR_CREATE_KHR_DEDICATED_ALLOCATION_BIT = 2,
    VMA_ALLOCATOR_CREATE_KHR_BIND_MEMORY2_BIT = 4,
    VMA_ALLOCATOR_CREATE_EXT_MEMORY_BUDGET_BIT = 8,
    VMA_ALLOCATOR_CREATE_AMD_DEVICE_COHERENT_MEMORY_BIT = 16,
    VMA_ALLOCATOR_CREATE_BUFFER_DEVICE_ADDRESS_BIT = 32,
    VMA_ALLOCATOR_CREATE_FLAG_BITS_MAX_ENUM = 2147483647,
    _,
};
pub const VmaAllocatorCreateFlagBits = enum_VmaAllocatorCreateFlagBits;
pub const VmaAllocatorCreateFlags = c.VkFlags;
pub const struct_VmaVulkanFunctions = extern struct {
    vkGetPhysicalDeviceProperties: c.PFN_vkGetPhysicalDeviceProperties,
    vkGetPhysicalDeviceMemoryProperties: c.PFN_vkGetPhysicalDeviceMemoryProperties,
    vkAllocateMemory: c.PFN_vkAllocateMemory,
    vkFreeMemory: c.PFN_vkFreeMemory,
    vkMapMemory: c.PFN_vkMapMemory,
    vkUnmapMemory: c.PFN_vkUnmapMemory,
    vkFlushMappedMemoryRanges: c.PFN_vkFlushMappedMemoryRanges,
    vkInvalidateMappedMemoryRanges: c.PFN_vkInvalidateMappedMemoryRanges,
    vkBindBufferMemory: c.PFN_vkBindBufferMemory,
    vkBindImageMemory: c.PFN_vkBindImageMemory,
    vkGetBufferMemoryRequirements: c.PFN_vkGetBufferMemoryRequirements,
    vkGetImageMemoryRequirements: c.PFN_vkGetImageMemoryRequirements,
    vkCreateBuffer: c.PFN_vkCreateBuffer,
    vkDestroyBuffer: c.PFN_vkDestroyBuffer,
    vkCreateImage: c.PFN_vkCreateImage,
    vkDestroyImage: c.PFN_vkDestroyImage,
    vkCmdCopyBuffer: c.PFN_vkCmdCopyBuffer,
    vkGetBufferMemoryRequirements2KHR: c.PFN_vkGetBufferMemoryRequirements2KHR,
    vkGetImageMemoryRequirements2KHR: c.PFN_vkGetImageMemoryRequirements2KHR,
    vkBindBufferMemory2KHR: c.PFN_vkBindBufferMemory2KHR,
    vkBindImageMemory2KHR: c.PFN_vkBindImageMemory2KHR,
    vkGetPhysicalDeviceMemoryProperties2KHR: c.PFN_vkGetPhysicalDeviceMemoryProperties2KHR,
};
pub const VmaVulkanFunctions = struct_VmaVulkanFunctions;
pub const VMA_RECORD_FLUSH_AFTER_CALL_BIT = @enumToInt(enum_VmaRecordFlagBits.VMA_RECORD_FLUSH_AFTER_CALL_BIT);
pub const VMA_RECORD_FLAG_BITS_MAX_ENUM = @enumToInt(enum_VmaRecordFlagBits.VMA_RECORD_FLAG_BITS_MAX_ENUM);
pub const enum_VmaRecordFlagBits = extern enum(c_int) {
    VMA_RECORD_FLUSH_AFTER_CALL_BIT = 1,
    VMA_RECORD_FLAG_BITS_MAX_ENUM = 2147483647,
    _,
};
pub const VmaRecordFlagBits = enum_VmaRecordFlagBits;
pub const VmaRecordFlags = c.VkFlags;
pub const struct_VmaRecordSettings = extern struct {
    flags: VmaRecordFlags,
    pFilePath: [*c]const u8,
};
pub const VmaRecordSettings = struct_VmaRecordSettings;
pub const struct_VmaAllocatorCreateInfo = extern struct {
    flags: VmaAllocatorCreateFlags,
    physicalDevice: c.VkPhysicalDevice,
    device: c.VkDevice,
    preferredLargeHeapBlockSize: c.VkDeviceSize,
    pAllocationCallbacks: [*c]const c.VkAllocationCallbacks,
    pDeviceMemoryCallbacks: [*c]const VmaDeviceMemoryCallbacks,
    frameInUseCount: u32,
    pHeapSizeLimit: [*c]const c.VkDeviceSize,
    pVulkanFunctions: [*c]const VmaVulkanFunctions,
    pRecordSettings: [*c]const VmaRecordSettings,
    instance: c.VkInstance,
    vulkanApiVersion: u32,
};
pub const VmaAllocatorCreateInfo = struct_VmaAllocatorCreateInfo;
pub extern fn vmaCreateAllocator(pCreateInfo: [*c]const VmaAllocatorCreateInfo, pAllocator: [*c]VmaAllocator) c.VkResult;
pub extern fn vmaDestroyAllocator(allocator: VmaAllocator) void;
pub const struct_VmaAllocatorInfo = extern struct {
    instance: c.VkInstance,
    physicalDevice: c.VkPhysicalDevice,
    device: c.VkDevice,
};
pub const VmaAllocatorInfo = struct_VmaAllocatorInfo;
pub extern fn vmaGetAllocatorInfo(allocator: VmaAllocator, pAllocatorInfo: [*c]VmaAllocatorInfo) void;
pub extern fn vmaGetPhysicalDeviceProperties(allocator: VmaAllocator, ppPhysicalDeviceProperties: [*c][*c]const c.VkPhysicalDeviceProperties) void;
pub extern fn vmaGetMemoryProperties(allocator: VmaAllocator, ppPhysicalDeviceMemoryProperties: [*c][*c]const c.VkPhysicalDeviceMemoryProperties) void;
pub extern fn vmaGetMemoryTypeProperties(allocator: VmaAllocator, memoryTypeIndex: u32, pFlags: [*c]c.VkMemoryPropertyFlags) void;
pub extern fn vmaSetCurrentFrameIndex(allocator: VmaAllocator, frameIndex: u32) void;
pub const struct_VmaStatInfo = extern struct {
    blockCount: u32,
    allocationCount: u32,
    unusedRangeCount: u32,
    usedBytes: c.VkDeviceSize,
    unusedBytes: c.VkDeviceSize,
    allocationSizeMin: c.VkDeviceSize,
    allocationSizeAvg: c.VkDeviceSize,
    allocationSizeMax: c.VkDeviceSize,
    unusedRangeSizeMin: c.VkDeviceSize,
    unusedRangeSizeAvg: c.VkDeviceSize,
    unusedRangeSizeMax: c.VkDeviceSize,
};
pub const VmaStatInfo = struct_VmaStatInfo;
pub const struct_VmaStats = extern struct {
    memoryType: [32]VmaStatInfo,
    memoryHeap: [16]VmaStatInfo,
    total: VmaStatInfo,
};
pub const VmaStats = struct_VmaStats;
pub extern fn vmaCalculateStats(allocator: VmaAllocator, pStats: [*c]VmaStats) void;
pub const struct_VmaBudget = extern struct {
    blockBytes: c.VkDeviceSize,
    allocationBytes: c.VkDeviceSize,
    usage: c.VkDeviceSize,
    budget: c.VkDeviceSize,
};
pub const VmaBudget = struct_VmaBudget;
pub extern fn vmaGetBudget(allocator: VmaAllocator, pBudget: [*c]VmaBudget) void;
pub extern fn vmaBuildStatsString(allocator: VmaAllocator, ppStatsString: [*c][*c]u8, detailedMap: c.VkBool32) void;
pub extern fn vmaFreeStatsString(allocator: VmaAllocator, pStatsString: [*c]u8) void;
pub const struct_VmaPool_T = @OpaqueType();
pub const VmaPool = ?*struct_VmaPool_T;
pub const VMA_MEMORY_USAGE_UNKNOWN = @enumToInt(enum_VmaMemoryUsage.VMA_MEMORY_USAGE_UNKNOWN);
pub const VMA_MEMORY_USAGE_GPU_ONLY = @enumToInt(enum_VmaMemoryUsage.VMA_MEMORY_USAGE_GPU_ONLY);
pub const VMA_MEMORY_USAGE_CPU_ONLY = @enumToInt(enum_VmaMemoryUsage.VMA_MEMORY_USAGE_CPU_ONLY);
pub const VMA_MEMORY_USAGE_CPU_TO_GPU = @enumToInt(enum_VmaMemoryUsage.VMA_MEMORY_USAGE_CPU_TO_GPU);
pub const VMA_MEMORY_USAGE_GPU_TO_CPU = @enumToInt(enum_VmaMemoryUsage.VMA_MEMORY_USAGE_GPU_TO_CPU);
pub const VMA_MEMORY_USAGE_CPU_COPY = @enumToInt(enum_VmaMemoryUsage.VMA_MEMORY_USAGE_CPU_COPY);
pub const VMA_MEMORY_USAGE_GPU_LAZILY_ALLOCATED = @enumToInt(enum_VmaMemoryUsage.VMA_MEMORY_USAGE_GPU_LAZILY_ALLOCATED);
pub const VMA_MEMORY_USAGE_MAX_ENUM = @enumToInt(enum_VmaMemoryUsage.VMA_MEMORY_USAGE_MAX_ENUM);
pub const enum_VmaMemoryUsage = extern enum(c_int) {
    VMA_MEMORY_USAGE_UNKNOWN = 0,
    VMA_MEMORY_USAGE_GPU_ONLY = 1,
    VMA_MEMORY_USAGE_CPU_ONLY = 2,
    VMA_MEMORY_USAGE_CPU_TO_GPU = 3,
    VMA_MEMORY_USAGE_GPU_TO_CPU = 4,
    VMA_MEMORY_USAGE_CPU_COPY = 5,
    VMA_MEMORY_USAGE_GPU_LAZILY_ALLOCATED = 6,
    VMA_MEMORY_USAGE_MAX_ENUM = 2147483647,
    _,
};
pub const VmaMemoryUsage = enum_VmaMemoryUsage;
pub const VMA_ALLOCATION_CREATE_DEDICATED_MEMORY_BIT = @enumToInt(enum_VmaAllocationCreateFlagBits.VMA_ALLOCATION_CREATE_DEDICATED_MEMORY_BIT);
pub const VMA_ALLOCATION_CREATE_NEVER_ALLOCATE_BIT = @enumToInt(enum_VmaAllocationCreateFlagBits.VMA_ALLOCATION_CREATE_NEVER_ALLOCATE_BIT);
pub const VMA_ALLOCATION_CREATE_MAPPED_BIT = @enumToInt(enum_VmaAllocationCreateFlagBits.VMA_ALLOCATION_CREATE_MAPPED_BIT);
pub const VMA_ALLOCATION_CREATE_CAN_BECOME_LOST_BIT = @enumToInt(enum_VmaAllocationCreateFlagBits.VMA_ALLOCATION_CREATE_CAN_BECOME_LOST_BIT);
pub const VMA_ALLOCATION_CREATE_CAN_MAKE_OTHER_LOST_BIT = @enumToInt(enum_VmaAllocationCreateFlagBits.VMA_ALLOCATION_CREATE_CAN_MAKE_OTHER_LOST_BIT);
pub const VMA_ALLOCATION_CREATE_USER_DATA_COPY_STRING_BIT = @enumToInt(enum_VmaAllocationCreateFlagBits.VMA_ALLOCATION_CREATE_USER_DATA_COPY_STRING_BIT);
pub const VMA_ALLOCATION_CREATE_UPPER_ADDRESS_BIT = @enumToInt(enum_VmaAllocationCreateFlagBits.VMA_ALLOCATION_CREATE_UPPER_ADDRESS_BIT);
pub const VMA_ALLOCATION_CREATE_DONT_BIND_BIT = @enumToInt(enum_VmaAllocationCreateFlagBits.VMA_ALLOCATION_CREATE_DONT_BIND_BIT);
pub const VMA_ALLOCATION_CREATE_WITHIN_BUDGET_BIT = @enumToInt(enum_VmaAllocationCreateFlagBits.VMA_ALLOCATION_CREATE_WITHIN_BUDGET_BIT);
pub const VMA_ALLOCATION_CREATE_STRATEGY_BEST_FIT_BIT = @enumToInt(enum_VmaAllocationCreateFlagBits.VMA_ALLOCATION_CREATE_STRATEGY_BEST_FIT_BIT);
pub const VMA_ALLOCATION_CREATE_STRATEGY_WORST_FIT_BIT = @enumToInt(enum_VmaAllocationCreateFlagBits.VMA_ALLOCATION_CREATE_STRATEGY_WORST_FIT_BIT);
pub const VMA_ALLOCATION_CREATE_STRATEGY_FIRST_FIT_BIT = @enumToInt(enum_VmaAllocationCreateFlagBits.VMA_ALLOCATION_CREATE_STRATEGY_FIRST_FIT_BIT);
pub const VMA_ALLOCATION_CREATE_STRATEGY_MIN_MEMORY_BIT = @enumToInt(enum_VmaAllocationCreateFlagBits.VMA_ALLOCATION_CREATE_STRATEGY_MIN_MEMORY_BIT);
pub const VMA_ALLOCATION_CREATE_STRATEGY_MIN_TIME_BIT = @enumToInt(enum_VmaAllocationCreateFlagBits.VMA_ALLOCATION_CREATE_STRATEGY_MIN_TIME_BIT);
pub const VMA_ALLOCATION_CREATE_STRATEGY_MIN_FRAGMENTATION_BIT = @enumToInt(enum_VmaAllocationCreateFlagBits.VMA_ALLOCATION_CREATE_STRATEGY_MIN_FRAGMENTATION_BIT);
pub const VMA_ALLOCATION_CREATE_STRATEGY_MASK = @enumToInt(enum_VmaAllocationCreateFlagBits.VMA_ALLOCATION_CREATE_STRATEGY_MASK);
pub const VMA_ALLOCATION_CREATE_FLAG_BITS_MAX_ENUM = @enumToInt(enum_VmaAllocationCreateFlagBits.VMA_ALLOCATION_CREATE_FLAG_BITS_MAX_ENUM);
pub const enum_VmaAllocationCreateFlagBits = extern enum(c_int) {
    VMA_ALLOCATION_CREATE_DEDICATED_MEMORY_BIT = 1,
    VMA_ALLOCATION_CREATE_NEVER_ALLOCATE_BIT = 2,
    VMA_ALLOCATION_CREATE_MAPPED_BIT = 4,
    VMA_ALLOCATION_CREATE_CAN_BECOME_LOST_BIT = 8,
    VMA_ALLOCATION_CREATE_CAN_MAKE_OTHER_LOST_BIT = 16,
    VMA_ALLOCATION_CREATE_USER_DATA_COPY_STRING_BIT = 32,
    VMA_ALLOCATION_CREATE_UPPER_ADDRESS_BIT = 64,
    VMA_ALLOCATION_CREATE_DONT_BIND_BIT = 128,
    VMA_ALLOCATION_CREATE_WITHIN_BUDGET_BIT = 256,
    VMA_ALLOCATION_CREATE_STRATEGY_BEST_FIT_BIT = 65536,
    VMA_ALLOCATION_CREATE_STRATEGY_WORST_FIT_BIT = 131072,
    VMA_ALLOCATION_CREATE_STRATEGY_FIRST_FIT_BIT = 262144,
    VMA_ALLOCATION_CREATE_STRATEGY_MIN_MEMORY_BIT = 65536,
    VMA_ALLOCATION_CREATE_STRATEGY_MIN_TIME_BIT = 262144,
    VMA_ALLOCATION_CREATE_STRATEGY_MIN_FRAGMENTATION_BIT = 131072,
    VMA_ALLOCATION_CREATE_STRATEGY_MASK = 458752,
    VMA_ALLOCATION_CREATE_FLAG_BITS_MAX_ENUM = 2147483647,
    _,
};
pub const VmaAllocationCreateFlagBits = enum_VmaAllocationCreateFlagBits;
pub const VmaAllocationCreateFlags = c.VkFlags;
pub const struct_VmaAllocationCreateInfo = extern struct {
    flags: VmaAllocationCreateFlags,
    usage: VmaMemoryUsage,
    requiredFlags: c.VkMemoryPropertyFlags,
    preferredFlags: c.VkMemoryPropertyFlags,
    memoryTypeBits: u32,
    pool: VmaPool,
    pUserData: ?*c_void,
};
pub const VmaAllocationCreateInfo = struct_VmaAllocationCreateInfo;
pub extern fn vmaFindMemoryTypeIndex(allocator: VmaAllocator, memoryTypeBits: u32, pAllocationCreateInfo: [*c]const VmaAllocationCreateInfo, pMemoryTypeIndex: [*c]u32) c.VkResult;
pub extern fn vmaFindMemoryTypeIndexForBufferInfo(allocator: VmaAllocator, pBufferCreateInfo: [*c]const VkBufferCreateInfo, pAllocationCreateInfo: [*c]const VmaAllocationCreateInfo, pMemoryTypeIndex: [*c]u32) c.VkResult;
pub extern fn vmaFindMemoryTypeIndexForImageInfo(allocator: VmaAllocator, pImageCreateInfo: [*c]const VkImageCreateInfo, pAllocationCreateInfo: [*c]const VmaAllocationCreateInfo, pMemoryTypeIndex: [*c]u32) c.VkResult;
pub const VMA_POOL_CREATE_IGNORE_BUFFER_IMAGE_GRANULARITY_BIT = @enumToInt(enum_VmaPoolCreateFlagBits.VMA_POOL_CREATE_IGNORE_BUFFER_IMAGE_GRANULARITY_BIT);
pub const VMA_POOL_CREATE_LINEAR_ALGORITHM_BIT = @enumToInt(enum_VmaPoolCreateFlagBits.VMA_POOL_CREATE_LINEAR_ALGORITHM_BIT);
pub const VMA_POOL_CREATE_BUDDY_ALGORITHM_BIT = @enumToInt(enum_VmaPoolCreateFlagBits.VMA_POOL_CREATE_BUDDY_ALGORITHM_BIT);
pub const VMA_POOL_CREATE_ALGORITHM_MASK = @enumToInt(enum_VmaPoolCreateFlagBits.VMA_POOL_CREATE_ALGORITHM_MASK);
pub const VMA_POOL_CREATE_FLAG_BITS_MAX_ENUM = @enumToInt(enum_VmaPoolCreateFlagBits.VMA_POOL_CREATE_FLAG_BITS_MAX_ENUM);
pub const enum_VmaPoolCreateFlagBits = extern enum(c_int) {
    VMA_POOL_CREATE_IGNORE_BUFFER_IMAGE_GRANULARITY_BIT = 2,
    VMA_POOL_CREATE_LINEAR_ALGORITHM_BIT = 4,
    VMA_POOL_CREATE_BUDDY_ALGORITHM_BIT = 8,
    VMA_POOL_CREATE_ALGORITHM_MASK = 12,
    VMA_POOL_CREATE_FLAG_BITS_MAX_ENUM = 2147483647,
    _,
};
pub const VmaPoolCreateFlagBits = enum_VmaPoolCreateFlagBits;
pub const VmaPoolCreateFlags = c.VkFlags;
pub const struct_VmaPoolCreateInfo = extern struct {
    memoryTypeIndex: u32,
    flags: VmaPoolCreateFlags,
    blockSize: c.VkDeviceSize,
    minBlockCount: usize,
    maxBlockCount: usize,
    frameInUseCount: u32,
};
pub const VmaPoolCreateInfo = struct_VmaPoolCreateInfo;
pub const struct_VmaPoolStats = extern struct {
    size: c.VkDeviceSize,
    unusedSize: c.VkDeviceSize,
    allocationCount: usize,
    unusedRangeCount: usize,
    unusedRangeSizeMax: c.VkDeviceSize,
    blockCount: usize,
};
pub const VmaPoolStats = struct_VmaPoolStats;
pub extern fn vmaCreatePool(allocator: VmaAllocator, pCreateInfo: [*c]const VmaPoolCreateInfo, pPool: [*c]VmaPool) c.VkResult;
pub extern fn vmaDestroyPool(allocator: VmaAllocator, pool: VmaPool) void;
pub extern fn vmaGetPoolStats(allocator: VmaAllocator, pool: VmaPool, pPoolStats: [*c]VmaPoolStats) void;
pub extern fn vmaMakePoolAllocationsLost(allocator: VmaAllocator, pool: VmaPool, pLostAllocationCount: [*c]usize) void;
pub extern fn vmaCheckPoolCorruption(allocator: VmaAllocator, pool: VmaPool) c.VkResult;
pub extern fn vmaGetPoolName(allocator: VmaAllocator, pool: VmaPool, ppName: [*c][*c]const u8) void;
pub extern fn vmaSetPoolName(allocator: VmaAllocator, pool: VmaPool, pName: [*c]const u8) void;
pub const struct_VmaAllocation_T = @OpaqueType();
pub const VmaAllocation = ?*struct_VmaAllocation_T;
pub const struct_VmaAllocationInfo = extern struct {
    memoryType: u32,
    deviceMemory: c.VkDeviceMemory,
    offset: c.VkDeviceSize,
    size: c.VkDeviceSize,
    pMappedData: ?*c_void,
    pUserData: ?*c_void,
};
pub const VmaAllocationInfo = struct_VmaAllocationInfo;
pub extern fn vmaAllocateMemory(allocator: VmaAllocator, pVkMemoryRequirements: [*c]const c.VkMemoryRequirements, pCreateInfo: [*c]const VmaAllocationCreateInfo, pAllocation: [*c]VmaAllocation, pAllocationInfo: [*c]VmaAllocationInfo) c.VkResult;
pub extern fn vmaAllocateMemoryPages(allocator: VmaAllocator, pVkMemoryRequirements: [*c]const c.VkMemoryRequirements, pCreateInfo: [*c]const VmaAllocationCreateInfo, allocationCount: usize, pAllocations: [*c]VmaAllocation, pAllocationInfo: [*c]VmaAllocationInfo) c.VkResult;
pub extern fn vmaAllocateMemoryForBuffer(allocator: VmaAllocator, buffer: c.VkBuffer, pCreateInfo: [*c]const VmaAllocationCreateInfo, pAllocation: [*c]VmaAllocation, pAllocationInfo: [*c]VmaAllocationInfo) c.VkResult;
pub extern fn vmaAllocateMemoryForImage(allocator: VmaAllocator, image: c.VkImage, pCreateInfo: [*c]const VmaAllocationCreateInfo, pAllocation: [*c]VmaAllocation, pAllocationInfo: [*c]VmaAllocationInfo) c.VkResult;
pub extern fn vmaFreeMemory(allocator: VmaAllocator, allocation: VmaAllocation) void;
pub extern fn vmaFreeMemoryPages(allocator: VmaAllocator, allocationCount: usize, pAllocations: [*c]const VmaAllocation) void;
pub extern fn vmaResizeAllocation(allocator: VmaAllocator, allocation: VmaAllocation, newSize: c.VkDeviceSize) c.VkResult;
pub extern fn vmaGetAllocationInfo(allocator: VmaAllocator, allocation: VmaAllocation, pAllocationInfo: [*c]VmaAllocationInfo) void;
pub extern fn vmaTouchAllocation(allocator: VmaAllocator, allocation: VmaAllocation) c.VkBool32;
pub extern fn vmaSetAllocationUserData(allocator: VmaAllocator, allocation: VmaAllocation, pUserData: ?*c_void) void;
pub extern fn vmaCreateLostAllocation(allocator: VmaAllocator, pAllocation: [*c]VmaAllocation) void;
pub extern fn vmaMapMemory(allocator: VmaAllocator, allocation: VmaAllocation, ppData: [*c]?*c_void) c.VkResult;
pub extern fn vmaUnmapMemory(allocator: VmaAllocator, allocation: VmaAllocation) void;
pub extern fn vmaFlushAllocation(allocator: VmaAllocator, allocation: VmaAllocation, offset: c.VkDeviceSize, size: c.VkDeviceSize) c.VkResult;
pub extern fn vmaInvalidateAllocation(allocator: VmaAllocator, allocation: VmaAllocation, offset: c.VkDeviceSize, size: c.VkDeviceSize) c.VkResult;
pub extern fn vmaFlushAllocations(allocator: VmaAllocator, allocationCount: u32, allocations: [*c]const VmaAllocation, offsets: [*c]const c.VkDeviceSize, sizes: [*c]const c.VkDeviceSize) c.VkResult;
pub extern fn vmaInvalidateAllocations(allocator: VmaAllocator, allocationCount: u32, allocations: [*c]const VmaAllocation, offsets: [*c]const c.VkDeviceSize, sizes: [*c]const c.VkDeviceSize) c.VkResult;
pub extern fn vmaCheckCorruption(allocator: VmaAllocator, memoryTypeBits: u32) c.VkResult;
pub const struct_VmaDefragmentationContext_T = @OpaqueType();
pub const VmaDefragmentationContext = ?*struct_VmaDefragmentationContext_T;
pub const VMA_DEFRAGMENTATION_FLAG_INCREMENTAL = @enumToInt(enum_VmaDefragmentationFlagBits.VMA_DEFRAGMENTATION_FLAG_INCREMENTAL);
pub const VMA_DEFRAGMENTATION_FLAG_BITS_MAX_ENUM = @enumToInt(enum_VmaDefragmentationFlagBits.VMA_DEFRAGMENTATION_FLAG_BITS_MAX_ENUM);
pub const enum_VmaDefragmentationFlagBits = extern enum(c_int) {
    VMA_DEFRAGMENTATION_FLAG_INCREMENTAL = 1,
    VMA_DEFRAGMENTATION_FLAG_BITS_MAX_ENUM = 2147483647,
    _,
};
pub const VmaDefragmentationFlagBits = enum_VmaDefragmentationFlagBits;
pub const VmaDefragmentationFlags = c.VkFlags;
pub const struct_VmaDefragmentationInfo2 = extern struct {
    flags: VmaDefragmentationFlags,
    allocationCount: u32,
    pAllocations: [*c]const VmaAllocation,
    pAllocationsChanged: [*c]c.VkBool32,
    poolCount: u32,
    pPools: [*c]const VmaPool,
    maxCpuBytesToMove: c.VkDeviceSize,
    maxCpuAllocationsToMove: u32,
    maxGpuBytesToMove: c.VkDeviceSize,
    maxGpuAllocationsToMove: u32,
    commandBuffer: c.VkCommandBuffer,
};
pub const VmaDefragmentationInfo2 = struct_VmaDefragmentationInfo2;
pub const struct_VmaDefragmentationPassMoveInfo = extern struct {
    allocation: VmaAllocation,
    memory: c.VkDeviceMemory,
    offset: c.VkDeviceSize,
};
pub const VmaDefragmentationPassMoveInfo = struct_VmaDefragmentationPassMoveInfo;
pub const struct_VmaDefragmentationPassInfo = extern struct {
    moveCount: u32,
    pMoves: [*c]VmaDefragmentationPassMoveInfo,
};
pub const VmaDefragmentationPassInfo = struct_VmaDefragmentationPassInfo;
pub const struct_VmaDefragmentationInfo = extern struct {
    maxBytesToMove: c.VkDeviceSize,
    maxAllocationsToMove: u32,
};
pub const VmaDefragmentationInfo = struct_VmaDefragmentationInfo;
pub const struct_VmaDefragmentationStats = extern struct {
    bytesMoved: c.VkDeviceSize,
    bytesFreed: c.VkDeviceSize,
    allocationsMoved: u32,
    deviceMemoryBlocksFreed: u32,
};
pub const VmaDefragmentationStats = struct_VmaDefragmentationStats;
pub extern fn vmaDefragmentationBegin(allocator: VmaAllocator, pInfo: [*c]const VmaDefragmentationInfo2, pStats: [*c]VmaDefragmentationStats, pContext: [*c]VmaDefragmentationContext) c.VkResult;
pub extern fn vmaDefragmentationEnd(allocator: VmaAllocator, context: VmaDefragmentationContext) c.VkResult;
pub extern fn vmaBeginDefragmentationPass(allocator: VmaAllocator, context: VmaDefragmentationContext, pInfo: [*c]VmaDefragmentationPassInfo) c.VkResult;
pub extern fn vmaEndDefragmentationPass(allocator: VmaAllocator, context: VmaDefragmentationContext) c.VkResult;
pub extern fn vmaDefragment(allocator: VmaAllocator, pAllocations: [*c]const VmaAllocation, allocationCount: usize, pAllocationsChanged: [*c]c.VkBool32, pDefragmentationInfo: [*c]const VmaDefragmentationInfo, pDefragmentationStats: [*c]VmaDefragmentationStats) c.VkResult;
pub extern fn vmaBindBufferMemory(allocator: VmaAllocator, allocation: VmaAllocation, buffer: c.VkBuffer) c.VkResult;
pub extern fn vmaBindBufferMemory2(allocator: VmaAllocator, allocation: VmaAllocation, allocationLocalOffset: c.VkDeviceSize, buffer: c.VkBuffer, pNext: ?*const c_void) c.VkResult;
pub extern fn vmaBindImageMemory(allocator: VmaAllocator, allocation: VmaAllocation, image: c.VkImage) c.VkResult;
pub extern fn vmaBindImageMemory2(allocator: VmaAllocator, allocation: VmaAllocation, allocationLocalOffset: c.VkDeviceSize, image: c.VkImage, pNext: ?*const c_void) c.VkResult;
pub extern fn vmaCreateBuffer(allocator: VmaAllocator, pBufferCreateInfo: [*c]const c.VkBufferCreateInfo, pAllocationCreateInfo: [*c]const VmaAllocationCreateInfo, pBuffer: [*c]c.VkBuffer, pAllocation: [*c]VmaAllocation, pAllocationInfo: [*c]VmaAllocationInfo) c.VkResult;
pub extern fn vmaDestroyBuffer(allocator: VmaAllocator, buffer: c.VkBuffer, allocation: VmaAllocation) void;
pub extern fn vmaCreateImage(allocator: VmaAllocator, pImageCreateInfo: [*c]const c.VkImageCreateInfo, pAllocationCreateInfo: [*c]const VmaAllocationCreateInfo, pImage: [*c]c.VkImage, pAllocation: [*c]VmaAllocation, pAllocationInfo: [*c]VmaAllocationInfo) c.VkResult;
pub extern fn vmaDestroyImage(allocator: VmaAllocator, image: c.VkImage, allocation: VmaAllocation) void;