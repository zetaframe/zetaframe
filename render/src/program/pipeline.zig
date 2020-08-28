const std = @import("std");
const Allocator = std.mem.Allocator;
const trait = std.meta.trait;

const vk = @import("../include/vk.zig");

const Render = @import("../lib.zig").Render;
const Context = @import("../backend/context.zig").Context;
const Pipeline = @import("../backend/pipeline.zig").Pipeline;
const RenderPass = @import("../backend/renderpass.zig").RenderPass;
const Framebuffer = @import("../backend/framebuffer.zig").Framebuffer;

const DescriptorSetLayout = @import("descriptor.zig").SetLayout;
const renderpass = @import("renderpass.zig");

pub const IObject = struct {
    executeFn: fn (self: *const IObject, cb: vk.CommandBuffer, fb: Framebuffer) anyerror!void,

    pub fn execute(self: *const IObject, cb: vk.CommandBuffer, fb: Framebuffer) !void {
        try self.executeFn(self, cb, fb);
    }
};

pub const State = struct {
    kind: vk.PipelineBindPoint,

    render_pass: type,
    layout: Layout,

    shader_stages: []const ShaderStage,

    vertex_input_state: VertexInputState,
    input_assembly_state: InputAssemblyState,
    rasterizer_state: RasterizerState,
    multisample_state: ?MultisampleState,
    depth_stencil_state: ?DepthStencilState,
    color_blend_state: ColorBlendState,

    /// Creates a new state with the specified overrides
    pub fn override(comptime self: *const State, comptime Override: anytype) State {
        comptime var new = State{
            .kind = self.kind,

            .render_pass = self.render_pass,
            .layout = self.layout,

            .shader_stages = self.shader_stages,

            .vertex_input_state = self.vertex_input_state,
            .input_assembly_state = self.input_assembly_state,
            .rasterizer_state = self.rasterizer_state,
            .multisample_state = self.multisample_state,
            .depth_stencil_state = self.depth_stencil_state,
            .color_blend_state = self.color_blend_state,
        };

        comptime for (@typeInfo(@TypeOf(Override)).Struct.fields) |field, i| {
            if (@hasField(State, field.name)) {
                if (std.mem.startsWith(u8, @typeName(field.field_type), "struct")) {
                    for (@typeInfo(field.field_type).Struct.fields) |inner_field, j| {
                        if (@hasField(@TypeOf(@field(new, field.name)), inner_field.name)) {
                            @field(@field(new, field.name), inner_field.name) = @field(@field(Override, field.name), inner_field.name);
                        }
                    }
                } else {
                    @field(new, field.name) = @field(Override, field.name);
                }
            }
        };

        return new;
    }
};

pub fn Object(comptime state: State) type {
    return struct {
        const Self = @This();

        base: IObject = .{
            .executeFn = execute,
        },
        context: *const Context,

        render_pass: *const state.render_pass,

        descriptor_set_layouts: [state.layout.set_layouts.len]vk.DescriptorSetLayout,
        shader_modules: [state.shader_stages.len]vk.ShaderModule,
        layout: vk.PipelineLayout,
        pipeline: vk.Pipeline,

        /// Build a pipeline object for use in a program
        pub fn build(render: *Render, render_pass: *const state.render_pass) !Self {
            const context = &render.backend.context;

            // create VertexInput info
            comptime var vertex_input_bindings: [state.vertex_input_state.bindings.len]vk.VertexInputBindingDescription = undefined;
            comptime const vertex_input_attributes_len = blk: {
                var len = 0;
                for (state.vertex_input_state.bindings) |T| {
                    len += @typeInfo(T).Struct.fields.len;
                }
                break :blk len;
            };
            comptime var vertex_input_attributes: [vertex_input_attributes_len]vk.VertexInputAttributeDescription = undefined;
            comptime for (state.vertex_input_state.bindings) |T, i| {
                if (!trait.is(.Struct)(T) or !(trait.isPacked(T) or trait.isExtern(T))) {
                    @compileError("Vertex Type must be a packed/extern struct");
                }

                var attribute_pos: usize = 0;
                for (@typeInfo(T).Struct.fields) |field, j| {
                    const format: vk.Format = switch (@typeInfo(field.field_type).Struct.fields[0].field_type) {
                        f32 => switch (@typeInfo(field.field_type).Struct.fields.len) {
                            1 => .r32_sfloat,
                            2 => .r32g32_sfloat,
                            3 => .r32g32b32_sfloat,
                            4 => .r32g32b32a32_sfloat,
                            else => @compileError("Invalid Type for Vertex Input"),
                        },
                        i32 => switch (@typeInfo(field.field_type).Struct.fields.len) {
                            1 => .r32_sint,
                            2 => .r32g32_sint,
                            3 => .r32g32b32_sint,
                            4 => .r32g32b32a32_sint,
                            else => @compileError("Invalid Type for Vertex Input"),
                        },
                        else => @compileError("Invalid Type for Vertex Input"),
                    };

                    vertex_input_attributes[attribute_pos] = vk.VertexInputAttributeDescription{
                        .location = @intCast(u32, j),
                        .binding = i,
                        .format = format,
                        .offset = @intCast(u32, @byteOffsetOf(T, field.name)),
                    };
                    attribute_pos += 1;
                }

                vertex_input_bindings[i] = vk.VertexInputBindingDescription{
                    .binding = i,
                    .stride = @sizeOf(T),
                    .input_rate = state.vertex_input_state.input_rate,
                };
            };

            const vertex_input_info = vk.PipelineVertexInputStateCreateInfo{
                .vertex_binding_description_count = @intCast(u32, state.vertex_input_state.bindings.len),
                .p_vertex_binding_descriptions = &vertex_input_bindings,

                .vertex_attribute_description_count = @intCast(u32, vertex_input_attributes_len),
                .p_vertex_attribute_descriptions = &vertex_input_attributes,

                .flags = .{},
            };

            // create InputAssembly info
            const input_assembly_info = vk.PipelineInputAssemblyStateCreateInfo{
                .topology = state.input_assembly_state.topology,
                .primitive_restart_enable = if (state.input_assembly_state.primitive_restart) vk.TRUE else vk.FALSE,

                .flags = .{},
            };

            // create Rasterizer info
            const rasterizer_info = vk.PipelineRasterizationStateCreateInfo{
                .depth_clamp_enable = vk.FALSE,

                .rasterizer_discard_enable = vk.FALSE,

                .polygon_mode = state.rasterizer_state.polygon_mode,

                .line_width = 1.0,

                .cull_mode = state.rasterizer_state.cull_mode,
                .front_face = state.rasterizer_state.front_face,

                .depth_bias_enable = vk.FALSE,
                .depth_bias_constant_factor = 0,
                .depth_bias_clamp = 0,
                .depth_bias_slope_factor = 0,

                .flags = .{},
            };

            // create Multisampling info
            const multisample_info = if (state.multisample_state) |multisample|
                vk.PipelineMultisampleStateCreateInfo{
                    .sample_shading_enable = vk.FALSE,

                    .rasterization_samples = .{ .@"1_bit" = true },

                    .min_sample_shading = 0,
                    .p_sample_mask = null,

                    .alpha_to_coverage_enable = 0,
                    .alpha_to_one_enable = 0,

                    .flags = .{},
                }
            else
                vk.PipelineMultisampleStateCreateInfo{
                    .sample_shading_enable = vk.FALSE,

                    .rasterization_samples = .{ .@"1_bit" = true },

                    .min_sample_shading = 0,
                    .p_sample_mask = null,

                    .alpha_to_coverage_enable = 0,
                    .alpha_to_one_enable = 0,

                    .flags = .{},
                };

            // create DepthStencil info
            const depth_stencil_info: ?vk.PipelineDepthStencilStateCreateInfo = if (state.depth_stencil_state) |depth_stencil| undefined else null;

            // create ColorBlend info
            comptime var color_blend_attachments: [state.color_blend_state.attachments.len]vk.PipelineColorBlendAttachmentState = undefined;
            comptime for (state.color_blend_state.attachments) |attachment, i| {
                color_blend_attachments[i] = vk.PipelineColorBlendAttachmentState{
                    .blend_enable = if (attachment.enable_blending) vk.TRUE else vk.FALSE,

                    .src_color_blend_factor = attachment.color_blend_src,
                    .dst_color_blend_factor = attachment.color_blend_dst,
                    .color_blend_op = attachment.color_blend_op,

                    .src_alpha_blend_factor = attachment.alpha_blend_src,
                    .dst_alpha_blend_factor = attachment.alpha_blend_dst,
                    .alpha_blend_op = attachment.alpha_blend_op,

                    .color_write_mask = attachment.color_write_mask,
                };
            };

            const color_blend_info = vk.PipelineColorBlendStateCreateInfo{
                .logic_op_enable = vk.FALSE,
                .logic_op = .copy,

                .attachment_count = color_blend_attachments.len,
                .p_attachments = &color_blend_attachments,

                .blend_constants = [_]f32{ 0, 0, 0, 0 },

                .flags = .{},
            };

            // create PipelineLayout
            var descriptor_set_layouts: [state.layout.set_layouts.len]vk.DescriptorSetLayout = undefined;
            inline for (state.layout.set_layouts) |set, i| {
                var set_bindings: [set.bindings.len]vk.DescriptorSetLayoutBinding = undefined;
                for (set.bindings) |binding, j| {
                    set_bindings[j] = vk.DescriptorSetLayoutBinding{
                        .binding = @intCast(u32, j),
                        .descriptor_type = binding.kind,
                        .descriptor_count = binding.count,
                        .stage_flags = binding.stages,

                        .p_immutable_samplers = null,
                    };
                }
                const set_info = vk.DescriptorSetLayoutCreateInfo{
                    .binding_count = set.bindings.len,
                    .p_bindings = &set_bindings,

                    .flags = .{},
                };

                descriptor_set_layouts[i] = try context.vkd.createDescriptorSetLayout(context.device, set_info, null);
            }
            const layout_info = vk.PipelineLayoutCreateInfo{
                .set_layout_count = state.layout.set_layouts.len,
                .p_set_layouts = if (state.layout.set_layouts.len == 0) undefined else &descriptor_set_layouts,

                .push_constant_range_count = 0,
                .p_push_constant_ranges = undefined,

                .flags = .{},
            };
            const layout = try context.vkd.createPipelineLayout(context.device, layout_info, null);

            // create Shader Modules
            var shader_modules: [state.shader_stages.len]vk.ShaderModule = undefined;
            var shader_infos: [state.shader_stages.len]vk.PipelineShaderStageCreateInfo = undefined;
            inline for (state.shader_stages) |stage, i| {
                const bytes = if (stage.shader == .bytes) stage.shader.bytes else try std.fs.cwd().readFileAllocOptions(&context.arena.allocator, stage.shader.path, std.math.maxInt(u32), @alignOf(u32), 0);
                const create_info = vk.ShaderModuleCreateInfo{
                    .code_size = bytes.len,
                    .p_code = @ptrCast([*]const u32, bytes),

                    .flags = .{},
                };

                shader_modules[i] = try context.vkd.createShaderModule(context.device, create_info, null);

                shader_infos[i] = vk.PipelineShaderStageCreateInfo{
                    .stage = stage.stage,
                    .module = shader_modules[i],
                    .p_name = stage.entrypoint[0..:0],

                    .flags = .{},
                    .p_specialization_info = null,
                };
            }

            // create fake Viewport info
            const viewport_info = vk.PipelineViewportStateCreateInfo{
                .viewport_count = 1,
                .p_viewports = null,

                .scissor_count = 1,
                .p_scissors = null,

                .flags = .{},
            };

            // create Dynamic info
            const dynamic_states = [_]vk.DynamicState{
                .viewport,
                .scissor,
            };
            const dynamic_info = vk.PipelineDynamicStateCreateInfo{
                .dynamic_state_count = dynamic_states.len,
                .p_dynamic_states = &dynamic_states,

                .flags = .{},
            };

            // create Pipeline
            const pipeline_info = [_]vk.GraphicsPipelineCreateInfo{vk.GraphicsPipelineCreateInfo{
                .stage_count = @intCast(u32, state.shader_stages.len),
                .p_stages = @ptrCast([*]const vk.PipelineShaderStageCreateInfo, &shader_infos),

                .p_tessellation_state = null,

                .p_vertex_input_state = &vertex_input_info,
                .p_input_assembly_state = &input_assembly_info,
                .p_viewport_state = &viewport_info,
                .p_rasterization_state = &rasterizer_info,
                .p_multisample_state = &multisample_info,
                .p_depth_stencil_state = null,
                .p_color_blend_state = &color_blend_info,
                .p_dynamic_state = &dynamic_info,

                .layout = layout,

                .render_pass = render_pass.render_pass,
                .subpass = 0,

                .base_pipeline_handle = .null_handle,
                .base_pipeline_index = 0,

                .flags = .{},
            }};
            var pipeline: vk.Pipeline = undefined;
            _ = try context.vkd.createGraphicsPipelines(context.device, .null_handle, pipeline_info.len, &pipeline_info, null, @ptrCast(*[1]vk.Pipeline, &pipeline));

            return Self{
                .context = context,

                .render_pass = render_pass,

                .descriptor_set_layouts = descriptor_set_layouts,
                .shader_modules = shader_modules,
                .layout = layout,
                .pipeline = pipeline,
            };
        }

        pub fn deinit(self: Self) void {
            self.context.vkd.destroyPipeline(self.context.device, self.pipeline, null);
            self.context.vkd.destroyPipelineLayout(self.context.device, self.layout, null);

            for (self.shader_modules) |module| self.context.vkd.destroyShaderModule(self.context.device, module, null);
            for (self.descriptor_set_layouts) |layout| self.context.vkd.destroyDescriptorSetLayout(self.context.device, layout, null);
        }

        pub fn execute(base: *const IObject, cb: vk.CommandBuffer, fb: Framebuffer) !void {
            const self = @fieldParentPtr(Self, "base", base);

            self.context.vkd.cmdBindPipeline(cb, state.kind, self.pipeline);
        }
    };
}

pub const Layout = struct {
    set_layouts: []const DescriptorSetLayout,
};

pub const ShaderStage = struct {
    stage: vk.ShaderStageFlags,
    shader: union(enum) {
        path: []const u8,
        bytes: [:0]align(@alignOf(u32)) const u8,
    },
    entrypoint: []const u8,
};

pub const VertexInputState = struct {
    input_rate: vk.VertexInputRate,
    bindings: []const type,
};

pub const InputAssemblyState = struct {
    topology: vk.PrimitiveTopology,
    primitive_restart: bool,
};

pub const RasterizerState = struct {
    cull_mode: vk.CullModeFlags,
    front_face: vk.FrontFace,
    polygon_mode: vk.PolygonMode,
};

pub const MultisampleState = struct {};

pub const DepthStencilState = struct {};

pub const ColorBlendState = struct {
    pub const Attachment = struct {
        enable_blending: bool,

        color_blend_src: vk.BlendFactor,
        color_blend_dst: vk.BlendFactor,
        color_blend_op: vk.BlendOp,

        alpha_blend_src: vk.BlendFactor,
        alpha_blend_dst: vk.BlendFactor,
        alpha_blend_op: vk.BlendOp,

        color_write_mask: vk.ColorComponentFlags,
    };

    attachments: []const Attachment,
};
