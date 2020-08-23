const std = @import("std");
const trait = std.meta.trait;
const Allocator = std.mem.Allocator;

const vk = @import("include/vk.zig");
const zva = @import("zva");

const BackendError = @import("backend/backend.zig").BackendError;

const Context = @import("backend/context.zig").Context;
const Buffer = @import("backend/buffer.zig").Buffer;
const Swapchain = @import("backend/swapchain.zig").Swapchain;
const RenderPass = @import("backend/renderpass.zig").RenderPass;
const Pipeline = @import("backend/pipeline.zig").Pipeline;
const Shader = @import("backend/shader.zig").Shader;

/// Defines the pipeline and shaders of a material
/// Use material instance to get an instance of this material
pub const Material = struct {
    pub const Shaders = struct {
        vertex: Shader,
        fragment: Shader,
    };

    const Self = @This();
    allocator: *Allocator,

    context: *const Context,

    pipeline: Pipeline,

    desc_layout: vk.DescriptorSetLayout,
    desc_set: vk.DescriptorSet,

    shaders: Shaders,

    pub fn new(shaders: Shaders, pipelineSettings: Pipeline.Settings) Self {
        return Self{
            .allocator = undefined,

            .context = undefined,

            .pipeline = Pipeline.new(pipelineSettings),

            .desc_layout = undefined,
            .desc_set = undefined,

            .shaders = shaders,
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, context: *const Context, renderPass: *RenderPass, swapchain: *Swapchain) !void {
        self.allocator = allocator;

        self.context = context;

        // const descBinding = vk.DescriptorSetLayoutBinding{
        //     .binding = if (self.shaders.vertex.refl.descriptor_sets[1].binding == self.shaders.fragment.refl.descriptor_sets[1].binding)
        //         self.shaders.fragment.refl.descriptor_sets[1].binding
        //     else
        //         return BackendError.InvalidShader,

        //     .descriptor_type = if (self.shaders.vertex.refl.descriptor_sets[1].kind == self.shaders.fragment.refl.descriptor_sets[1].kind)
        //         self.shaders.fragment.refl.descriptor_sets[1].kind
        //     else
        //         return BackendError.InvalidShader,
        //     .descriptor_count = 1,

        //     .stage_flags = .{ .vertex_bit = true, .fragment_bit = true },
        //     .p_immutable_samplers = null,
        // };
        // const layoutInfo = vk.DescriptorSetLayoutCreateInfo{
        //     .binding_count = 1,
        //     .p_bindings = @ptrCast([*]const vk.DescriptorSetLayoutBinding, &descBinding),

        //     .flags = .{},
        // };
        // self.desc_layout = try self.context.vkd.createDescriptorSetLayout(context.device, layoutInfo, null);

        try self.pipeline.init(allocator, context);
        try self.pipeline.addShader(self.shaders.vertex);
        try self.pipeline.addShader(self.shaders.fragment);
        try self.pipeline.createPipeline(renderPass);
    }

    pub fn deinit(self: Self) void {
        self.pipeline.deinit();

        // self.context.vkd.destroyDescriptorSetLayout(self.context.device, self.desc_layout, null);

        self.shaders.fragment.deinit();
        self.shaders.vertex.deinit();
    }
};

pub const InstancedMaterial = struct {
    const Self = @This();
    initFn: fn (self: *Self, vallocator: *zva.Allocator) anyerror!void,

    pub fn init(self: *Self, vallocator: *zva.Allocator) !void {
        self.initFn(self, vallocator);
    }
};

pub fn MaterialInstance(comptime T: type) type {
    return struct {
        const Self = @This();
        im: InstancedMaterial,

        vallocator: *zva.Allocator,

        material: *Material,

        buffer: Buffer,

        pub fn new(material: *Material) Self {
            return Self{
                .im = .{ .initFn = init },

                .vallocator = undefined,

                .material = material,

                .buffer = undefined,
                .allocation = undefined,
            };
        }

        pub fn init(im: *InstancedMaterial, vallocator: *zva.Allocator) !void {
            const self = @fieldParentPtr(Self, "im", im);

            self.vallocator = vallocator;
        }
    };
}
