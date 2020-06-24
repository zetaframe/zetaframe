const std = @import("std");
const trait = std.meta.trait;
const Allocator = std.mem.Allocator;

const shader = @import("../backend/shader.zig");

const vkbackend = @import("../backend/backend.zig");
const VulkanError = vkbackend.VulkanError;

const vk = @import("../include/vk.zig");
const VK_SUCCESS = vk.Result.SUCCESS;

const vma = @import("../include/vma.zig");

const Gpu = @import("../backend/gpu.zig").Gpu;
const Buffer = @import("../backend/buffer.zig").Buffer;

const RenderPass = @import("../backend/renderpass.zig").RenderPass;
const Pipeline = @import("../backend/pipeline.zig").Pipeline;

/// Defines the pipeline and shaders of a material
/// Use material instance to get an instance of this material
pub const Material = struct {
    pub const Description = struct {
        pub const Shaders = struct {
            vertex: vkbackend.Shader,
            fragment: vkbackend.Shader,
        };

        shaders: Shaders,
    };

    const Self = @This();
    allocator: *Allocator,

    description: Description,

    gpu: *Gpu,

    render_pass: RenderPass,
    pipeline: Pipeline,

    pub fn new(description: Description, pipelineSettings: Pipeline.Settings) Self {
        return Self{
            .allocator = undefined,
            
            .description = description,

            .gpu = undefined,

            .render_pass = RenderPass.new(),
            .pipeline = Pipeline.new(pipelineSettings, description.shaders.vertex, description.shaders.fragment),
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, gpu: *Gpu, rendercore: *RenderCore) !void {
        self.allocator = allocator;

        self.gpu = gpu;

        try self.render_pass.init(gpu, rendercore.swapchain.image_format);
        try self.pipeline.init(allocator, gpu, extent, rendercore.swapchain.image_format, self.render_pass.render_pass, size);
    }

    pub fn deinit(self: Self) void {
        self.pipeline.deinit();
        self.render_pass.deinit();
    }

    pub fn bindPipeline(self: *Self, command_buffer: vk.CommandBuffer) void {
        vk.CmdBindPipeline(command_buffer, .GRAPHICS, self.pipeline.pipeline);
    }
};

pub const MaterialInstance = struct {
    const Self = @This();
    allocator: *Allocator,
    vallocator: *vma.Allocator,

    material: *Material,

    desc_pool: vk.DescriptorPool,
    desc_set_layout: vk.DescriptorSetLayout,

    pub fn init(allocator: *Allocator, vallocator: *vma.Allocator, material: *Material) Self {
        return Self{
            .allocator = allocator,
            .vallocator = vallocator,

            .material = material,
        };
    }
};