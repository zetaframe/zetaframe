const std = @import("std");
const trait = std.meta.trait;

const Allocator = std.mem.Allocator;

const shader = @import("shader.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const vk = @import("../include/vk.zig");
const VK_SUCCESS = vk.Result.SUCCESS;

const vma = @import("../include/vma.zig");

const Gpu = @import("gpu.zig").Gpu;
const Buffer = @import("buffer.zig").Buffer;

const RenderPass = @import("render_pass.zig").RenderPass;
const Pipeline = @import("pipeline.zig").Pipeline;
/// Defines the pipeline and shaders of a material
/// Use material instance to get an instance of this material
// Basically a shader wrapper
pub const Material = struct {
    pub const Description = struct {
        pub const Shaders = struct {
            vertex: vkbackend.Shader,
            fragment: vkbackend.Shader,
        };

        pub const Input = struct {
            pub const BindingDescription = struct {
                binding: u32,
                stride: u32,
            };

            pub const AttributeDescription = struct {
                format: vk.Format,
                offset: u32,
            };

            binding_description: BindingDescription,
            attribute_descriptions: []AttributeDescription,

            /// Generates a Vertex Input Description from a type
            pub fn generateFromType(comptime T: type, binding: u32) !Input {
                if (comptime !trait.is(.Struct)(T)) {
                    @compileError("Vertex Type must be a packed/extern struct");
                }
                if (comptime !(trait.isPacked(T) or trait.isExtern(T))) {
                    @compileError("Vertex Type must be a packed/extern struct");
                }

                var attributeDescriptions = std.ArrayList(AttributeDescription).init(allocator);

                inline for (@typeInfo(T).Struct.fields) |field, i| {
                    var format: vk.Format = undefined;
                    switch (@typeInfo(field.field_type).Struct.fields[0].field_type) {
                        f32 => switch (@typeInfo(field.field_type).Struct.fields.len) {
                            1 => format = .R32_SFLOAT,
                            2 => format = .R32G32_SFLOAT,
                            3 => format = .R32G32B32_SFLOAT,
                            4 => format = .R32G32B32A32_SFLOAT,
                            else => @compileError("Invalid Type for Vertex Input"),
                        },
                        i32 => switch (@typeInfo(field.field_type).Struct.fields.len) {
                            1 => format = .R32_SINT,
                            2 => format = .R32G32_SINT,
                            3 => format = .R32G32B32_SINT,
                            4 => format = .R32G32B32A32_SINT,
                            else => @compileError("Invalid Type for Vertex Input"),
                        },
                        else => @compileError("Invalid Type for Vertex Input"),
                    }
                    try attributeDescriptions.append(AttributeDescription{
                        .format = format,
                        .offset = @intCast(u32, @byteOffsetOf(T, field.name)),
                    });
                }

                const ret = Input{
                    .binding_description = BindingDescription{
                        .binding = binding,
                        .stride = @sizeOf(T),
                    },
                    .attribute_descriptions = attributeDescriptions.toOwnedSlice(),
                };

                attributeDescriptions.deinit();

                return ret;
            }
        };

        pub const Assembly = struct {
            topology: vk.PrimitiveTopology,
        };

        pub const Rasterizer = struct {};

        shaders: Shaders,
        inputs: []Input,
        assembly: Assembly,
        rasterizer: Rasterizer,

        pub fn deinit(self: Description, allocator: *Allocator) void {
            for (self.inputs) |input| {
                allocator.free(input.attribute_descriptions);
            }
        }
    };

    const Self = @This();
    allocator: *Allocator,

    description: Description,

    gpu: *Gpu,

    render_pass: RenderPass,
    pipeline: Pipeline,

    pub fn new(description: Description) Self {
        return Self{
            .allocator = undefined,
            
            .description = description,

            .gpu = undefined,

            .render_pass = RenderPass.new(),
            .pipeline = Pipeline.new(description),
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, gpu: *Gpu, extent: vk.Extent2D, swapchainImageFormat: vk.Format, size: windowing.Size) !void {
        self.allocator = allocator;

        self.gpu = gpu;

        try self.render_pass.init(allocator, gpu, swapchainImageFormat);
        try self.pipeline.init(allocator, gpu, extent, swapchainImageFormat, self.render_pass.render_pass, size);
    }

    pub fn deinit(self: Self) void {
        self.pipeline.deinit();
        self.render_pass.deinit();
    }

    pub fn bindPipeline(self: *Self, command_buffer: vk.CommandBuffer, bind_point: vk.PipelineBindPoint) void {
        vk.vkCmdBindPipeline(command_buffer, bind_point, self.pipeline.pipeline);
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