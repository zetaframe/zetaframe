const std = @import("std");

const Allocator = std.mem.Allocator;

const shader = @import("shader.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const vk = @import("../include/vk.zig");
const VK_SUCCESS = vk.Result.SUCCESS;

const vma = @import("../include/vma.zig");

const Gpu = @import("gpu.zig").Gpu;
const Buffer = @import("buffer.zig").Buffer;

const Pipeline = @import("pipeline.zig").Pipeline;

pub const Material = struct {
    pub const Desciption = struct {
        shader_stages: struct {
            vertex: vkbackend.Shader,
            fragment: vkbackend.Shader,
        };      
    };

    const Self = @This();
    allocator: *Allocator,
    vallocator: *vma.Allocator,

    gpu: Gpu,

    pipeline: Pipeline,
    
    pub fn new(desciption: Desciption, pipelineSettings: Pipeline.Settings) Self {
        return Self{
            .allocator = undefined,
            .vallocator = undefined,

            .gpu = undefined,

            .pipeline = Pipeline.new(pipelineSettings, description.shader_stages.vertex, description.shader_stages.fragment),
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, vallocator: *vma.Allocator, gpu: Gpu, extent: vk.Extent2D, swapchainImageFormat: vk.Format, renderPass: vk.RenderPass, size: windowing.Size) !void {
        self.allocator = allocator;
        self.vallocator = vallocator;

        self.gpu = gpu;

        self.pipeline.init(allocator, gpu, extent, swapchainImageFormat, renderPass, size);
    }

    pub fn deinit(self: Self) void {
        self.pipeline.deinit();
    }
};

test "serial" {
    std.debug.warn("\n", .{});
}

test "deserial" {
    std.debug.warn("\n", .{});
}