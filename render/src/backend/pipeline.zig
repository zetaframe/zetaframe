const std = @import("std");
const trait = std.meta.trait;
const Allocator = std.mem.Allocator;

const windowing = @import("../windowing.zig");

const shader = @import("shader.zig");
const VulkanError = @import("backend.zig").VulkanError;

const vk = @import("../include/vk.zig");
const VK_SUCCESS = vk.enum_VkResult.VK_SUCCESS;

const Gpu = @import("gpu.zig").Gpu;
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

    gpu: *Gpu,

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

            .gpu = undefined,

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

    pub fn init(self: *Self, allocator: *Allocator, gpu: *Gpu, renderPass: *RenderPass) !void {
        self.allocator = allocator;

        self.gpu = gpu;

        try self.createProgrammable();
        try self.createFixed();

        const pipelineLayoutInfo = vk.PipelineLayoutCreateInfo{
            .setLayoutCount = 0,
            .pSetLayouts = undefined,

            .pushConstantRangeCount = 0,
            .pPushConstantRanges = undefined,
        };

        self.pipeline_layout = try vk.CreatePipelineLayout(self.gpu.device, pipelineLayoutInfo, null);

        const pipelineInfo = [_]vk.GraphicsPipelineCreateInfo{vk.GraphicsPipelineCreateInfo{
            .stageCount = @intCast(u32, self.shader_stages.len),
            .pStages = &self.shader_stages,

            .pTessellationState = null,

            .pVertexInputState = &self.vertex_input_info,
            .pInputAssemblyState = &self.input_assembly_info,
            .pViewportState = &self.viewport_info,
            .pRasterizationState = &self.rasterizer_info,
            .pMultisampleState = &self.multisampling_info,
            .pDepthStencilState = null,
            .pColorBlendState = &self.color_blend_info,
            .pDynamicState = &self.dynamic_info,

            .layout = self.pipeline_layout,

            .renderPass = renderPass.render_pass,
            .subpass = 0,

            .basePipelineHandle = .Null,
            .basePipelineIndex = 0,
        }};

        try vk.CreateGraphicsPipelines(self.gpu.device, .Null, &pipelineInfo, null, @ptrCast(*[1]vk.Pipeline, &self.pipeline));
    }

    pub fn deinit(self: Self) void {
        vk.DestroyPipeline(self.gpu.device, self.pipeline, null);
        vk.DestroyPipelineLayout(self.gpu.device, self.pipeline_layout, null);

        vk.DestroyShaderModule(self.gpu.device, self.vert_shader_module, null);
        vk.DestroyShaderModule(self.gpu.device, self.fragment_shader_module, null);

        self.vertex_binding_desciptions.deinit();
        self.vertex_attribute_desciptions.deinit();
    }

    fn createProgrammable(self: *Self) !void {
        const vertCreateInfo = vk.ShaderModuleCreateInfo{
            .codeSize = self.vert_shader.shader_bytes.len,
            .pCode = std.mem.bytesAsSlice(u32, self.vert_shader.shader_bytes).ptr,
        };

        self.vert_shader_module = try vk.CreateShaderModule(self.gpu.device, vertCreateInfo, null);

        self.vert_shader_stage_info = vk.PipelineShaderStageCreateInfo{
            .stage = vk.ShaderStageFlags{ .vertex = true },
            .module = self.vert_shader_module,
            .pName = "main",
        };

        const fragCreateInfo = vk.ShaderModuleCreateInfo{
            .codeSize = self.fragment_shader.shader_bytes.len,
            .pCode = std.mem.bytesAsSlice(u32, self.fragment_shader.shader_bytes).ptr,
        };

        self.fragment_shader_module = try vk.CreateShaderModule(self.gpu.device, fragCreateInfo, null);

        self.fragment_shader_stage_info = vk.PipelineShaderStageCreateInfo{
            .stage = vk.ShaderStageFlags{ .fragment = true },
            .module = self.fragment_shader_module,
            .pName = "main",
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
                .inputRate = .VERTEX,
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
            .vertexBindingDescriptionCount = @intCast(u32, self.vertex_binding_desciptions.items.len),
            .pVertexBindingDescriptions = self.vertex_binding_desciptions.items.ptr,

            .vertexAttributeDescriptionCount = @intCast(u32, self.vertex_attribute_desciptions.items.len),
            .pVertexAttributeDescriptions = self.vertex_attribute_desciptions.items.ptr,
        };

        self.input_assembly_info = vk.PipelineInputAssemblyStateCreateInfo{
            .topology = @intToEnum(vk.PrimitiveTopology, @enumToInt(self.settings.assembly.topology)),

            .primitiveRestartEnable = vk.FALSE,
        };

        self.viewport_info = vk.PipelineViewportStateCreateInfo{
            .viewportCount = 1,
            .pViewports = null,

            .scissorCount = 1,
            .pScissors = null,
        };

        self.rasterizer_info = vk.PipelineRasterizationStateCreateInfo{
            .depthClampEnable = vk.FALSE,

            .rasterizerDiscardEnable = vk.FALSE,

            .polygonMode = .FILL,

            .lineWidth = 1.0,

            .cullMode = switch (self.settings.rasterizer.cull_mode) {
                .Front => vk.CullModeFlags{ .front = true },
                .Back => vk.CullModeFlags{ .back = true },
                .Both => vk.CullModeFlags.frontAndBack,
                .None => vk.CullModeFlags.none,
            },
            .frontFace = switch (self.settings.rasterizer.front_face) {
                .Clockwise => vk.FrontFace.CLOCKWISE,
                .CounterClockwise => vk.FrontFace.COUNTER_CLOCKWISE,
            },

            .depthBiasEnable = vk.FALSE,
            .depthBiasConstantFactor = 0,
            .depthBiasClamp = 0,
            .depthBiasSlopeFactor = 0,
        };

        self.multisampling_info = vk.PipelineMultisampleStateCreateInfo{
            .sampleShadingEnable = vk.FALSE,

            .rasterizationSamples = vk.SampleCountFlags{ .t1 = true },

            .minSampleShading = 0,
            .pSampleMask = null,

            .alphaToCoverageEnable = 0,
            .alphaToOneEnable = 0,
        };

        const colorBlendAttachments = [_]vk.PipelineColorBlendAttachmentState{vk.PipelineColorBlendAttachmentState{
            .colorWriteMask = vk.ColorComponentFlags{ .r = true, .g = true, .b = true, .a = true },
            .blendEnable = vk.FALSE,

            .srcColorBlendFactor = .ZERO,
            .dstColorBlendFactor = .ZERO,
            .colorBlendOp = .ADD,

            .srcAlphaBlendFactor = .ZERO,
            .dstAlphaBlendFactor = .ZERO,
            .alphaBlendOp = .ADD,
        }};

        self.color_blend_info = vk.PipelineColorBlendStateCreateInfo{
            .logicOpEnable = vk.FALSE,
            .logicOp = .COPY,

            .attachmentCount = colorBlendAttachments.len,
            .pAttachments = &colorBlendAttachments,

            .blendConstants = [_]f32{ 0, 0, 0, 0 },
        };

        const dynamicStates = [_]vk.DynamicState{
            .VIEWPORT,
            .SCISSOR,
        };

        self.dynamic_info = vk.PipelineDynamicStateCreateInfo{
            .dynamicStateCount = dynamicStates.len,
            .pDynamicStates = &dynamicStates,
        };
    }
};
