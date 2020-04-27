const std = @import("std");

const Allocator = std.mem.Allocator;

const windowing = @import("../../windowing.zig");

const backend = @import("../backend.zig");
const VulkanError = @import("backend.zig").VulkanError;

const vk = @import("../../include/vk.zig");
const VK_SUCCESS = vk.enum_VkResult.VK_SUCCESS;

const Vertex = @import("../../vertex.zig").VkVertex2d;
const Gpu = @import("gpu.zig").Gpu;

pub const Pipeline = struct {
    const Self = @This();
    allocator: *Allocator,

    pipeline: vk.Pipeline,

    gpu: Gpu,
    extent: vk.Extent2D,
    swapchain_image_format: vk.Format,
    size: windowing.Size,

    vert_shader: backend.Shader,
    vert_shader_module: vk.ShaderModule,
    vert_shader_stage_info: vk.PipelineShaderStageCreateInfo,

    fragment_shader: backend.Shader,
    fragment_shader_module: vk.ShaderModule,
    fragment_shader_stage_info: vk.PipelineShaderStageCreateInfo,

    shader_stages: [2]vk.PipelineShaderStageCreateInfo,

    vertex_input_info: vk.PipelineVertexInputStateCreateInfo,
    input_assembly_info: vk.PipelineInputAssemblyStateCreateInfo,
    viewport_info: vk.PipelineViewportStateCreateInfo,
    rasterizer_info: vk.PipelineRasterizationStateCreateInfo,
    multisampling_info: vk.PipelineMultisampleStateCreateInfo,
    color_blend_info: vk.PipelineColorBlendStateCreateInfo,
    dynamic_info: vk.PipelineDynamicStateCreateInfo,

    pipeline_layout: vk.PipelineLayout,

    pub fn new(vert_shader: backend.Shader, fragment_shader: backend.Shader) Self {
        return Self{
            .allocator = undefined,

            .pipeline = undefined,

            .gpu = undefined,
            .extent = undefined,
            .swapchain_image_format = undefined,
            .size = undefined,

            .vert_shader = vert_shader,
            .vert_shader_module = undefined,
            .vert_shader_stage_info = undefined,

            .fragment_shader = fragment_shader,
            .fragment_shader_module = undefined,
            .fragment_shader_stage_info = undefined,

            .shader_stages = undefined,

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

    pub fn init(self: *Self, allocator: *Allocator, gpu: Gpu, extent: vk.Extent2D, swapchainImageFormat: vk.Format, renderPass: vk.RenderPass, size: windowing.Size) !void {
        self.allocator = allocator;

        self.gpu = gpu;
        self.extent = extent;
        self.swapchain_image_format = swapchainImageFormat;
        self.size = size;

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

            .renderPass = renderPass,
            .subpass = 0,

            .basePipelineHandle = null,
            .basePipelineIndex = 0,
        }};

        try vk.CreateGraphicsPipelines(self.gpu.device, null, &pipelineInfo, null, @ptrCast(*[1]vk.Pipeline, &self.pipeline));
    }

    pub fn deinit(self: Self) void {
        vk.DestroyPipeline(self.gpu.device, self.pipeline, null);
        vk.DestroyPipelineLayout(self.gpu.device, self.pipeline_layout, null);

        vk.DestroyShaderModule(self.gpu.device, self.vert_shader_module, null);
        vk.DestroyShaderModule(self.gpu.device, self.fragment_shader_module, null);
    }

    fn createProgrammable(self: *Self) !void {
        const vertCreateInfo = vk.ShaderModuleCreateInfo{
            .codeSize = self.vert_shader.shader_bytes.len,
            .pCode = std.mem.bytesAsSlice(u32, self.vert_shader.shader_bytes).ptr,
        };

        self.vert_shader_module = try vk.CreateShaderModule(self.gpu.device, vertCreateInfo, null);

        self.vert_shader_stage_info = vk.PipelineShaderStageCreateInfo{
            .stage = vk.ShaderStageFlags{.vertex = true},
            .module = self.vert_shader_module,
            .pName = "main",
        };

        const fragCreateInfo = vk.ShaderModuleCreateInfo{
            .codeSize = self.fragment_shader.shader_bytes.len,
            .pCode = std.mem.bytesAsSlice(u32, self.fragment_shader.shader_bytes).ptr,
        };

        self.fragment_shader_module = try vk.CreateShaderModule(self.gpu.device, fragCreateInfo, null);

        self.fragment_shader_stage_info = vk.PipelineShaderStageCreateInfo{
            .stage = vk.ShaderStageFlags{.fragment = true},
            .module = self.fragment_shader_module,
            .pName = "main",
        };

        self.shader_stages = [2]vk.PipelineShaderStageCreateInfo{ self.vert_shader_stage_info, self.fragment_shader_stage_info };
    }

    fn createFixed(self: *Self) !void {
        const bindingDescriptions = [_]vk.VertexInputBindingDescription{vk.VertexInputBindingDescription{
            .binding = 0,
            .stride = @sizeOf(Vertex),
            .inputRate = .VERTEX,
        }};
        const attributeDescriptions = [2]vk.VertexInputAttributeDescription{
            vk.VertexInputAttributeDescription{
                .binding = 0,
                .location = 0,
                .format = .R32G32_SFLOAT,
                .offset = @byteOffsetOf(Vertex, "pos"),
            },
            vk.VertexInputAttributeDescription{
                .binding = 0,
                .location = 1,
                .format = .R32G32B32_SFLOAT,
                .offset = @byteOffsetOf(Vertex, "color"),
            },
        };

        self.vertex_input_info = vk.PipelineVertexInputStateCreateInfo{
            .vertexBindingDescriptionCount = 1,
            .pVertexBindingDescriptions = &bindingDescriptions,

            .vertexAttributeDescriptionCount = attributeDescriptions.len,
            .pVertexAttributeDescriptions = &attributeDescriptions,
        };

        self.input_assembly_info = vk.PipelineInputAssemblyStateCreateInfo{
            .topology = .TRIANGLE_LIST,

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

            .cullMode = vk.CullModeFlags{.back = true},
            .frontFace = .CLOCKWISE,

            .depthBiasEnable = vk.FALSE,
            .depthBiasConstantFactor = 0,
            .depthBiasClamp = 0,
            .depthBiasSlopeFactor = 0,
        };

        self.multisampling_info = vk.PipelineMultisampleStateCreateInfo{
            .sampleShadingEnable = vk.FALSE,

            .rasterizationSamples = vk.SampleCountFlags{.t1 = true},

            .minSampleShading = 0,
            .pSampleMask = null,

            .alphaToCoverageEnable = 0,
            .alphaToOneEnable = 0,
        };

        const colorBlendAttachments = [_]vk.PipelineColorBlendAttachmentState{vk.PipelineColorBlendAttachmentState{
            .colorWriteMask = vk.ColorComponentFlags{.r = true, .g = true, .b = true, .a = true},
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
