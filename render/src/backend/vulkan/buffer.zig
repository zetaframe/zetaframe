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

pub fn VertexBuffer(comptime T: type) type {
    return struct {
        const Self = @This();
        buf: Buffer,

        allocator: *Allocator,
        vallocator: *vma.VmaAllocator,

        gpu: Gpu,

        sbuffer: c.VkBuffer,
        sallocation: vma.VmaAllocation,

        vbuffer: c.VkBuffer,
        vallocation: vma.VmaAllocation,

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

                .vbuffer = undefined,
                .vallocation = undefined,

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

            const sBufferInfo = c.VkBufferCreateInfo{
                .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,

                .size = self.size,

                .usage = @intCast(u32, c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT),
                .sharingMode = .VK_SHARING_MODE_EXCLUSIVE,

                .queueFamilyIndexCount = 0,
                .pQueueFamilyIndices = null,

                .pNext = null,
                .flags = 0,
            };

            const sAllocInfo = vma.VmaAllocationCreateInfo{
                .usage = vma.enum_VmaMemoryUsage.VMA_MEMORY_USAGE_CPU_TO_GPU,

                .requiredFlags = c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                .preferredFlags = 0,

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

            const vBufferInfo = c.VkBufferCreateInfo{
                .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,

                .size = self.size,

                .usage = @intCast(u32, c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT),
                .sharingMode = .VK_SHARING_MODE_CONCURRENT,

                .queueFamilyIndexCount = 2,
                .pQueueFamilyIndices = &[_]u32{gpu.indices.graphics_family.?, gpu.indices.transfer_family.?},

                .pNext = null,
                .flags = 0,
            };

            const vAllocInfo = vma.VmaAllocationCreateInfo{
                .usage = vma.enum_VmaMemoryUsage.VMA_MEMORY_USAGE_GPU_ONLY,

                .requiredFlags = c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                .preferredFlags = 0,

                .memoryTypeBits = 0,

                .pool = null,

                .pUserData = null,

                .flags = 0,
            };

            if (vma.vmaCreateBuffer(self.vallocator.*, &vBufferInfo, &vAllocInfo, &self.vbuffer, &self.vallocation, null) != VK_SUCCESS) {
                return VulkanError.CreateBufferFailed;
            }

            try self.copyBuffer();

            vma.vmaDestroyBuffer(self.vallocator.*, self.sbuffer, self.sallocation);
        }

        pub fn deinit(buf: *Buffer) void {
            const self = @fieldParentPtr(Self, "buf", buf);
            vma.vmaDestroyBuffer(self.vallocator.*, self.vbuffer, self.vallocation);
        }

        pub fn copyBuffer(self: *Self) !void {
            const allocInfo = c.VkCommandBufferAllocateInfo{
                .sType = .VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,

                .level = .VK_COMMAND_BUFFER_LEVEL_PRIMARY,

                .commandPool = self.gpu.transfer_pool,

                .commandBufferCount = 1,

                .pNext = null,
            };

            var commandBuffer: c.VkCommandBuffer = undefined;
            if (c.vkAllocateCommandBuffers(self.gpu.device, &allocInfo, &commandBuffer) != VK_SUCCESS) {
                return VulkanError.AllocCommandBuffersFailed;
            }
            
            const beginInfo = c.VkCommandBufferBeginInfo{
                .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,

                .pInheritanceInfo = null,

                .pNext = null,
                .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
            };

            if (c.vkBeginCommandBuffer(commandBuffer, &beginInfo) != VK_SUCCESS) {
                return VulkanError.BeginRecordCommandBufferFailed;
            }

            const copyRegion = c.VkBufferCopy{
                .srcOffset = 0,
                .dstOffset = 0,

                .size = self.size,
            };

            c.vkCmdCopyBuffer(commandBuffer, self.sbuffer, self.vbuffer, 1, &copyRegion);

            if (c.vkEndCommandBuffer(commandBuffer) != VK_SUCCESS) {
                return VulkanError.RecordCommandBufferFailed;
            }

            const submitInfo = c.VkSubmitInfo{
                .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_SUBMIT_INFO,

                .waitSemaphoreCount = 0,
                .pWaitSemaphores = null,
                .pWaitDstStageMask = null,

                .commandBufferCount = 1,
                .pCommandBuffers = &commandBuffer,

                .signalSemaphoreCount = 0,
                .pSignalSemaphores = null,

                .pNext = null,
            };

            if(c.vkQueueSubmit(self.gpu.transfer_queue, 1, &submitInfo, null) != VK_SUCCESS) {
                return VulkanError.SubmitBufferFailed;
            }
            _ = c.vkQueueWaitIdle(self.gpu.transfer_queue);

            c.vkFreeCommandBuffers(self.gpu.device, self.gpu.transfer_pool, 1, &commandBuffer);
        }

        pub fn buffer(buf: *Buffer) c.VkBuffer {
            const self = @fieldParentPtr(Self, "buf", buf);

            return self.vbuffer;
        }

        pub fn len(buf: *Buffer) u32 {
            const self = @fieldParentPtr(Self, "buf", buf);

            return self.len;
        }
    };
}