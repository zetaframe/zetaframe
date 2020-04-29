const std = @import("std");

const Allocator = std.mem.Allocator;

const backend = @import("../backend.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const vk = @import("../../include/vk.zig");
const VK_SUCCESS = vk.Result.SUCCESS;

const vma = @import("../../include/vma.zig");

const Gpu = @import("gpu.zig").Gpu;
const Buffer = @import("buffer.zig").Buffer;

pub const Uniform = struct {
    const Self = @This();
    allocator: *Allocator,
    vallocator: *vma.Allocator,

    gpu: Gpu,
    
    pub fn new() Self {
        return Self{

        };
    }
};