const std = @import("std");

const Allocator = std.mem.Allocator;

const shader = @import("shader.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const vk = @import("../include/vk.zig");
const VK_SUCCESS = vk.Result.SUCCESS;

const zva = @import("zva");

const Gpu = @import("gpu.zig").Gpu;
const Buffer = @import("buffer.zig").Buffer;

pub const Uniform = struct {
    const Self = @This();

    pub fn new(comptime T: type, allocator: *Allocator) Self {
        return Self{
            .allocator = undefined,
            .vallocator = undefined,

            .gpu = undefined,
        };
    }
};