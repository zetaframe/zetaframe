const std = @import("std");
const trait = std.meta.trait;
const Allocator = std.mem.Allocator;

const windowing = @import("../windowing.zig");

const shader = @import("shader.zig");
const VulkanError = @import("backend.zig").VulkanError;

const vk = @import("../include/vk.zig");

const Context = @import("context.zig").Context;
const Shader = @import("shader.zig").Shader;
const RenderPass = @import("renderpass.zig").RenderPass;

pub const Pipeline = struct {
    pub const Settings = struct {
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
            pub fn generateFromType(comptime T: type, comptime binding: u32) Input {
                if (comptime !trait.is(.Struct)(T)) {
                    @compileError("Vertex Type must be a packed/extern struct");
                }
                if (comptime !(trait.isPacked(T) or trait.isExtern(T))) {
                    @compileError("Vertex Type must be a packed/extern struct");
                }

                comptime {
                    var attributeDescriptions: [@typeInfo(T).Struct.fields.len]AttributeDescription = undefined;

                    for (@typeInfo(T).Struct.fields) |field, i| {
                        var format: vk.Format = undefined;
                        switch (@typeInfo(field.field_type).Struct.fields[0].field_type) {
                            f32 => switch (@typeInfo(field.field_type).Struct.fields.len) {
                                1 => format = .r32_sfloat,
                                2 => format = .r32g32_sfloat,
                                3 => format = .r32g32b32_sfloat,
                                4 => format = .r32g32b32a32_sfloat,
                                else => @compileError("Invalid Type for Vertex Input"),
                            },
                            i32 => switch (@typeInfo(field.field_type).Struct.fields.len) {
                                1 => format = .r32_sint,
                                2 => format = .r32g32_sint,
                                3 => format = .r32g32b32_sint,
                                4 => format = .r32g32b32a32_sint,
                                else => @compileError("Invalid Type for Vertex Input"),
                            },
                            else => @compileError("Invalid Type for Vertex Input"),
                        }
                        attributeDescriptions[i] = AttributeDescription{
                            .format = format,
                            .offset = @intCast(u32, @byteOffsetOf(T, field.name)),
                        };
                    }

                    const ret = Input{
                        .binding_description = BindingDescription{
                            .binding = binding,
                            .stride = @sizeOf(T),
                        },
                        .attribute_descriptions = attributeDescriptions[0..attributeDescriptions.len],
                    };

                    return ret;
                }
            }
        };

        pub const Assembly = struct {
            pub const Topology = enum(i32) {
                PointList,
                LineList,
                LineStrip,
                TriangleList,
                TriangleStrip,
                TriangleFan,
                LineListWithAdjacency,
                LineStripWithAdjacency,
                TriangleListWithAdjacency,
                TriangleStripWithAdjacency,
                PatchList,
            };

            topology: Topology,
        };

        pub const Rasterizer = struct {
            pub const CullMode = enum {
                Front,
                Back,
                Both,
                None,
            };

            pub const FrontFace = enum {
                Clockwise,
                CounterClockwise,
            };

            cull_mode: CullMode,
            front_face: FrontFace,
        };

        inputs: []Input,
        assembly: Assembly,
        rasterizer: Rasterizer,
    };

    const Self = @This();
    allocator: *Allocator,

    settings: Settings,

    pipeline: vk.Pipeline,

    context: *const Context,

    vert_shader: shader.Shader,
    vert_shader_module: vk.ShaderModule,
    vert_shader_stage_info: vk.PipelineShaderStageCreateInfo,

    fragment_shader: shader.Shader,
    fragment_shader_module: vk.ShaderModule,
    fragment_shader_stage_info: vk.PipelineShaderStageCreateInfo,

    shader_stages: [2]vk.PipelineShaderStageCreateInfo,

    vertex_binding_desciptions: std.ArrayList(vk.VertexInputBindingDescription),
    vertex_attribute_desciptions: std.ArrayList(vk.VertexInputAttributeDescription),
    vertex_input_info: vk.PipelineVertexInputStateCreateInfo,
    input_assembly_info: vk.PipelineInputAssemblyStateCreateInfo,
    viewport_info: vk.PipelineViewportStateCreateInfo,
    rasterizer_info: vk.PipelineRasterizationStateCreateInfo,
    multisampling_info: vk.PipelineMultisampleStateCreateInfo,
    color_blend_info: vk.PipelineColorBlendStateCreateInfo,
    dynamic_info: vk.PipelineDynamicStateCreateInfo,

    pipeline_layout: vk.PipelineLayout,

    pub fn new(settings: Settings, vertShader: Shader, fragShader: Shader) Self {
        return Self{
            .allocator = undefined,

            .settings = settings,

            .pipeline = undefined,

            .context = undefined,

            .vert_shader = vertShader,
            .vert_shader_module = undefined,
            .vert_shader_stage_info = undefined,

            .fragment_shader = fragShader,
            .fragment_shader_module = undefined,
            .fragment_shader_stage_info = undefined,

            .shader_stages = undefined,

            .vertex_binding_desciptions = undefined,
            .vertex_attribute_desciptions = undefined,
            .vertex_input_info = undefined,
            .input_assembly_info = undefined,
            .viewport_info = undefined,
            .rasterizer_info = undefined,
            .multisampling_info = undefined,
            .color_blend_info = undefined,
            .dynamic_info = undefined,

            .pipeline_layout = undefined,
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, context: *const Context, renderPass: *RenderPass) !void {
        self.allocator = allocator;

        self.context = context;

        try self.createProgrammable();
        try self.createFixed();

        const pipelineLayoutInfo = vk.PipelineLayoutCreateInfo{
            .set_layout_count = 0,
            .p_set_layouts = undefined,

            .push_constant_range_count = 0,
            .p_push_constant_ranges = undefined,

            .flags = .{},
        };

        self.pipeline_layout = try self.context.vkd.createPipelineLayout(self.context.device, pipelineLayoutInfo, null);

        const pipelineInfo = [_]vk.GraphicsPipelineCreateInfo{vk.GraphicsPipelineCreateInfo{
            .stage_count = @intCast(u32, self.shader_stages.len),
            .p_stages = &self.shader_stages,

            .p_tessellation_state = null,

            .p_vertex_input_state = &self.vertex_input_info,
            .p_input_assembly_state = &self.input_assembly_info,
            .p_viewport_state = &self.viewport_info,
            .p_rasterization_state = &self.rasterizer_info,
            .p_multisample_state = &self.multisampling_info,
            .p_depth_stencil_state = null,
            .p_color_blend_state = &self.color_blend_info,
            .p_dynamic_state = &self.dynamic_info,

            .layout = self.pipeline_layout,

            .render_pass = renderPass.render_pass,
            .subpass = 0,

            .base_pipeline_handle = .null_handle,
            .base_pipeline_index = 0,

            .flags = .{},
        }};

        _ = try self.context.vkd.createGraphicsPipelines(self.context.device, .null_handle, pipelineInfo.len, &pipelineInfo, null, @ptrCast(*[1]vk.Pipeline, &self.pipeline));
    }

    pub fn deinit(self: Self) void {
        self.context.vkd.destroyPipeline(self.context.device, self.pipeline, null);
        self.context.vkd.destroyPipelineLayout(self.context.device, self.pipeline_layout, null);

        self.context.vkd.destroyShaderModule(self.context.device, self.vert_shader_module, null);
        self.context.vkd.destroyShaderModule(self.context.device, self.fragment_shader_module, null);

        self.vertex_binding_desciptions.deinit();
        self.vertex_attribute_desciptions.deinit();
    }

    fn createProgrammable(self: *Self) !void {
        const vertCreateInfo = vk.ShaderModuleCreateInfo{
            .code_size = self.vert_shader.shader_bytes.len,
            .p_code = @ptrCast([*]const u32, self.vert_shader.shader_bytes),

            .flags = .{},
        };

        self.vert_shader_module = try self.context.vkd.createShaderModule(self.context.device, vertCreateInfo, null);

        self.vert_shader_stage_info = vk.PipelineShaderStageCreateInfo{
            .stage = .{ .vertex_bit = true },
            .module = self.vert_shader_module,
            .p_name = "main",

            .flags = .{},
            .p_specialization_info = null,
        };

        const fragCreateInfo = vk.ShaderModuleCreateInfo{
            .code_size = self.fragment_shader.shader_bytes.len,
            .p_code = @ptrCast([*]const u32, self.fragment_shader.shader_bytes),

            .flags = .{},
        };

        self.fragment_shader_module = try self.context.vkd.createShaderModule(self.context.device, fragCreateInfo, null);

        self.fragment_shader_stage_info = vk.PipelineShaderStageCreateInfo{
            .stage = .{ .fragment_bit = true },
            .module = self.fragment_shader_module,
            .p_name = "main",

            .flags = .{},
            .p_specialization_info = null,
        };

        self.shader_stages = [2]vk.PipelineShaderStageCreateInfo{ self.vert_shader_stage_info, self.fragment_shader_stage_info };
    }

    fn createFixed(self: *Self) !void {
        self.vertex_binding_desciptions = std.ArrayList(vk.VertexInputBindingDescription).init(self.allocator);
        self.vertex_attribute_desciptions = std.ArrayList(vk.VertexInputAttributeDescription).init(self.allocator);

        for (self.settings.inputs) |input, i| {
            try self.vertex_binding_desciptions.append(vk.VertexInputBindingDescription{
                .binding = self.settings.inputs[i].binding_description.binding,
                .stride = self.settings.inputs[i].binding_description.stride,
                .input_rate = .vertex,
            });

            for (self.settings.inputs[i].attribute_descriptions) |desc, j| {
                try self.vertex_attribute_desciptions.append(vk.VertexInputAttributeDescription{
                    .binding = self.settings.inputs[i].binding_description.binding,
                    .location = @intCast(u32, j),
                    .format = self.settings.inputs[i].attribute_descriptions[j].format,
                    .offset = self.settings.inputs[i].attribute_descriptions[j].offset,
                });
            }
        }

        self.vertex_input_info = vk.PipelineVertexInputStateCreateInfo{
            .vertex_binding_description_count = @intCast(u32, self.vertex_binding_desciptions.items.len),
            .p_vertex_binding_descriptions = self.vertex_binding_desciptions.items.ptr,

            .vertex_attribute_description_count = @intCast(u32, self.vertex_attribute_desciptions.items.len),
            .p_vertex_attribute_descriptions = self.vertex_attribute_desciptions.items.ptr,

            .flags = .{},
        };

        self.input_assembly_info = vk.PipelineInputAssemblyStateCreateInfo{
            .topology = @intToEnum(vk.PrimitiveTopology, @enumToInt(self.settings.assembly.topology)),

            .primitive_restart_enable = vk.FALSE,

            .flags = .{},
        };

        self.viewport_info = vk.PipelineViewportStateCreateInfo{
            .viewport_count = 1,
            .p_viewports = null,

            .scissor_count = 1,
            .p_scissors = null,

            .flags = .{},
        };

        self.rasterizer_info = vk.PipelineRasterizationStateCreateInfo{
            .depth_clamp_enable = vk.FALSE,

            .rasterizer_discard_enable = vk.FALSE,

            .polygon_mode = .fill,

            .line_width = 1.0,

            .cull_mode = switch (self.settings.rasterizer.cull_mode) {
                .Front => .{ .front_bit = true },
                .Back => .{ .back_bit = true },
                .Both => .{ .front_bit = true, .back_bit = true },
                .None => .{},
            },
            .front_face = switch (self.settings.rasterizer.front_face) {
                .Clockwise => .clockwise,
                .CounterClockwise => .counter_clockwise,
            },

            .depth_bias_enable = vk.FALSE,
            .depth_bias_constant_factor = 0,
            .depth_bias_clamp = 0,
            .depth_bias_slope_factor = 0,

            .flags = .{},
        };

        self.multisampling_info = vk.PipelineMultisampleStateCreateInfo{
            .sample_shading_enable = vk.FALSE,

            .rasterization_samples = .{ .@"1_bit" = true },

            .min_sample_shading = 0,
            .p_sample_mask = null,

            .alpha_to_coverage_enable = 0,
            .alpha_to_one_enable = 0,

            .flags = .{},
        };

        const colorBlendAttachments = [_]vk.PipelineColorBlendAttachmentState{vk.PipelineColorBlendAttachmentState{
            .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
            .blend_enable = vk.FALSE,

            .src_color_blend_factor = .zero,
            .dst_color_blend_factor = .zero,
            .color_blend_op = .add,

            .src_alpha_blend_factor = .zero,
            .dst_alpha_blend_factor = .zero,
            .alpha_blend_op = .add,
        }};

        self.color_blend_info = vk.PipelineColorBlendStateCreateInfo{
            .logic_op_enable = vk.FALSE,
            .logic_op = .copy,

            .attachment_count = colorBlendAttachments.len,
            .p_attachments = &colorBlendAttachments,

            .blend_constants = [_]f32{ 0, 0, 0, 0 },

            .flags = .{},
        };

        const dynamicStates = [_]vk.DynamicState{
            .viewport,
            .scissor,
        };

        self.dynamic_info = vk.PipelineDynamicStateCreateInfo{
            .dynamic_state_count = dynamicStates.len,
            .p_dynamic_states = &dynamicStates,

            .flags = .{},
        };
    }
};
