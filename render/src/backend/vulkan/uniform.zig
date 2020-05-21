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
      
    pub fn new(comptime T: type, allocator: *Allocator) Self {
        


        return Self{
            .allocator = undefined,
            .vallocator = undefined,

            .gpu = undefined,
        };
    }
};

pub const UniformManager = struct {
    const Self = @This();
    allocator: *Allocator,
    vallocator: *vma.Allocator,

    gpu: Gpu,
    
    pub fn new() Self {

        return Self{
            .allocator = undefined,
            .vallocator = undefined,

            .gpu = undefined,
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, vallocator: *vma.Allocator, gpu: Gpu) !void {
        self.allocator = allocator;
        self.vallocator = vallocator;

        self.gpu = gpu;
    }

    pub fn deinit(self: Self) void {

    }
};