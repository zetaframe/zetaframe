const std = @import("std");
const trait = std.meta.trait;
const Allocator = std.mem.Allocator;

const shader = @import("../backend/shader.zig");

const vkbackend = @import("../backend/backend.zig");
const VulkanError = vkbackend.VulkanError;

const vk = @import("../include/vk.zig");

const vma = @import("../include/vma.zig");

const Context = @import("../backend/context.zig").Context;
const Buffer = @import("../backend/buffer.zig").Buffer;
const Swapchain = @import("../backend/swapchain.zig").Swapchain;
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

    context: *Context,

    pipeline: Pipeline,

    pub fn new(description: Description, pipelineSettings: Pipeline.Settings) Self {
        return Self{
            .allocator = undefined,

            .description = description,

            .context = undefined,

            .pipeline = Pipeline.new(pipelineSettings, description.shaders.vertex, description.shaders.fragment),
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, context: *Context, renderPass: *RenderPass, swapchain: *Swapchain) !void {
        self.allocator = allocator;

        self.context = context;

        try self.pipeline.init(allocator, context, renderPass);
    }

    pub fn deinit(self: Self) void {
        self.pipeline.deinit();

        self.description.shaders.fragment.deinit();
        self.description.shaders.vertex.deinit();
    }
};

pub const MaterialInstance = struct {
    const Self = @This();
    allocator: *Allocator,
    vallocator: *vma.Allocator,

    material: *Material,

    desc_pool: vk.DescriptorPool,
    desc_set_layout: vk.DescriptorSetLayout,

    pub fn new(material: *Material) Self {
        return Self{
            .allocator = undefined,
            .vallocator = undefined,

            .material = material,

            .desc_pool = undefined,
            .desc_set_layout = undefined,
        };
    }

    pub fn init(allocator: *Allocator, vallocator: *vma.Allocator) !void {
        
    }
};
