const std = @import("std");

const Allocator = std.mem.Allocator;

const windowing = @import("../../windowing.zig");

const backend = @import("../backend.zig");
const VulkanError = @import("backend.zig").VulkanError;

const c = @import("../../c2.zig");
const VK_SUCCESS = c.enum_VkResult.VK_SUCCESS;

const Vertex = @import("../../vertex.zig").VkVertex2d;
const Gpu = @import("gpu.zig").Gpu;

pub const Pipeline = struct {
    const Self = @This();
    allocator: *Allocator,

    pipeline: c.VkPipeline,

    gpu: Gpu,
    extent: c.VkExtent2D,
    swapchain_image_format: c.VkFormat,
    size: windowing.Size,

    vert_shader: backend.Shader,
    vert_shader_module: c.VkShaderModule,
    vert_shader_stage_info: c.VkPipelineShaderStageCreateInfo,

    fragment_shader: backend.Shader,
    fragment_shader_module: c.VkShaderModule,
    fragment_shader_stage_info: c.VkPipelineShaderStageCreateInfo,

    shader_stages: [2]c.VkPipelineShaderStageCreateInfo,

    vertex_input_info: c.VkPipelineVertexInputStateCreateInfo,
    input_assembly_info: c.VkPipelineInputAssemblyStateCreateInfo,
    viewport_info: c.VkPipelineViewportStateCreateInfo,
    rasterizer_info: c.VkPipelineRasterizationStateCreateInfo,
    multisampling_info: c.VkPipelineMultisampleStateCreateInfo,
    color_blend_info: c.VkPipelineColorBlendStateCreateInfo,
    dynamic_info: c.VkPipelineDynamicStateCreateInfo,

    pipeline_layout: c.VkPipelineLayout,

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

    pub fn init(self: *Self, allocator: *Allocator, gpu: Gpu, extent: c.VkExtent2D, swapchainImageFormat: c.VkFormat, renderPass: c.VkRenderPass, size: windowing.Size) !void {
        self.allocator = allocator;

        self.gpu = gpu;
        self.extent = extent;
        self.swapchain_image_format = swapchainImageFormat;
        self.size = size;

        try self.createProgrammable();
        try self.createFixed();

        const pipelineLayoutInfo = c.VkPipelineLayoutCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,

            .setLayoutCount = 0,
            .pushConstantRangeCount = 0,

            .pSetLayouts = null,
            .pPushConstantRanges = null,

            .pNext = null,
            .flags = 0,
        };

        if (c.vkCreatePipelineLayout(self.gpu.device, &pipelineLayoutInfo, null, &self.pipeline_layout) != VK_SUCCESS) {
            return VulkanError.CreatePipelineLayoutFailed;
        }

        const pipelineInfo = [_]c.VkGraphicsPipelineCreateInfo{c.VkGraphicsPipelineCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,

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

            .pNext = null,
            .flags = 0,
        }};

        if (c.vkCreateGraphicsPipelines(self.gpu.device, null, @intCast(u32, pipelineInfo.len), &pipelineInfo, null, &self.pipeline) != VK_SUCCESS) {
            return VulkanError.CreateGraphicsPipelineFailed;
        }
    }

    pub fn deinit(self: Self) void {
        c.vkDestroyPipeline(self.gpu.device, self.pipeline, null);
        c.vkDestroyPipelineLayout(self.gpu.device, self.pipeline_layout, null);

        c.vkDestroyShaderModule(self.gpu.device, self.vert_shader_module, null);
        c.vkDestroyShaderModule(self.gpu.device, self.fragment_shader_module, null);
    }

    fn createProgrammable(self: *Self) !void {
        const vertCreateInfo = c.VkShaderModuleCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,

            .codeSize = self.vert_shader.shader_bytes.len,
            .pCode = std.mem.bytesAsSlice(u32, self.vert_shader.shader_bytes).ptr,

            .pNext = null,
            .flags = 0,
        };

        if (c.vkCreateShaderModule(self.gpu.device, &vertCreateInfo, null, &self.vert_shader_module) != VK_SUCCESS) {
            return VulkanError.CreateShaderModuleFailed;
        }

        self.vert_shader_stage_info = c.VkPipelineShaderStageCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,

            .stage = c.enum_VkShaderStageFlagBits.VK_SHADER_STAGE_VERTEX_BIT,
            .module = self.vert_shader_module,
            .pName = "main",

            .pNext = null,
            .flags = 0,
            .pSpecializationInfo = null,
        };

        const fragCreateInfo = c.VkShaderModuleCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,

            .codeSize = self.fragment_shader.shader_bytes.len,
            .pCode = std.mem.bytesAsSlice(u32, self.fragment_shader.shader_bytes).ptr,

            .pNext = null,
            .flags = 0,
        };

        if (c.vkCreateShaderModule(self.gpu.device, &fragCreateInfo, null, &self.fragment_shader_module) != VK_SUCCESS) {
            return VulkanError.CreateShaderModuleFailed;
        }

        self.fragment_shader_stage_info = c.VkPipelineShaderStageCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,

            .stage = c.enum_VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT,
            .module = self.fragment_shader_module,
            .pName = "main",

            .pNext = null,
            .flags = 0,
            .pSpecializationInfo = null,
        };

        self.shader_stages = [2]c.VkPipelineShaderStageCreateInfo{ self.vert_shader_stage_info, self.fragment_shader_stage_info };
    }

    fn createFixed(self: *Self) !void {
        const bindingDescription = c.VkVertexInputBindingDescription{
            .binding = 0,
            .stride = @sizeOf(Vertex),
            .inputRate = c.enum_VkVertexInputRate.VK_VERTEX_INPUT_RATE_VERTEX,
        };
        const attributeDescriptions = [2]c.VkVertexInputAttributeDescription{
            c.VkVertexInputAttributeDescription{
                .binding = 0,
                .location = 0,
                .format = c.enum_VkFormat.VK_FORMAT_R32G32_SFLOAT,
                .offset = @byteOffsetOf(Vertex, "pos"),
            },
            c.VkVertexInputAttributeDescription{
                .binding = 0,
                .location = 1,
                .format = c.enum_VkFormat.VK_FORMAT_R32G32B32_SFLOAT,
                .offset = @byteOffsetOf(Vertex, "color"),
            },
        };

        self.vertex_input_info = c.VkPipelineVertexInputStateCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,

            .vertexBindingDescriptionCount = 1,
            .pVertexBindingDescriptions = &bindingDescription,

            .vertexAttributeDescriptionCount = attributeDescriptions.len,
            .pVertexAttributeDescriptions = &attributeDescriptions,

            .pNext = null,
            .flags = 0,
        };

        self.input_assembly_info = c.VkPipelineInputAssemblyStateCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,

            .topology = c.enum_VkPrimitiveTopology.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,

            .primitiveRestartEnable = c.VK_FALSE,

            .pNext = null,
            .flags = 0,
        };

        self.viewport_info = c.VkPipelineViewportStateCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,

            .viewportCount = 1,
            .pViewports = null,

            .scissorCount = 1,
            .pScissors = null,

            .pNext = null,
            .flags = 0,
        };

        self.rasterizer_info = c.VkPipelineRasterizationStateCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,

            .depthClampEnable = c.VK_FALSE,

            .rasterizerDiscardEnable = c.VK_FALSE,

            .polygonMode = c.enum_VkPolygonMode.VK_POLYGON_MODE_FILL,

            .lineWidth = 1.0,

            .cullMode = @intCast(u32, c.VK_CULL_MODE_BACK_BIT),
            .frontFace = c.enum_VkFrontFace.VK_FRONT_FACE_CLOCKWISE,

            .depthBiasEnable = c.VK_FALSE,
            .depthBiasConstantFactor = 0,
            .depthBiasClamp = 0,
            .depthBiasSlopeFactor = 0,

            .pNext = null,
            .flags = 0,
        };

        self.multisampling_info = c.VkPipelineMultisampleStateCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,

            .sampleShadingEnable = c.VK_FALSE,

            .rasterizationSamples = c.enum_VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,

            .minSampleShading = 0,
            .pSampleMask = null,

            .alphaToCoverageEnable = 0,
            .alphaToOneEnable = 0,

            .pNext = null,
            .flags = 0,
        };

        const colorBlendAttachments = [_]c.VkPipelineColorBlendAttachmentState{c.VkPipelineColorBlendAttachmentState{
            .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
            .blendEnable = c.VK_FALSE,

            .srcColorBlendFactor = c.enum_VkBlendFactor.VK_BLEND_FACTOR_ZERO,
            .dstColorBlendFactor = c.enum_VkBlendFactor.VK_BLEND_FACTOR_ZERO,
            .colorBlendOp = c.enum_VkBlendOp.VK_BLEND_OP_ADD,

            .srcAlphaBlendFactor = c.enum_VkBlendFactor.VK_BLEND_FACTOR_ZERO,
            .dstAlphaBlendFactor = c.enum_VkBlendFactor.VK_BLEND_FACTOR_ZERO,
            .alphaBlendOp = c.enum_VkBlendOp.VK_BLEND_OP_ADD,
        }};

        self.color_blend_info = c.VkPipelineColorBlendStateCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,

            .logicOpEnable = c.VK_FALSE,
            .logicOp = c.enum_VkLogicOp.VK_LOGIC_OP_COPY,

            .attachmentCount = colorBlendAttachments.len,
            .pAttachments = &colorBlendAttachments,

            .blendConstants = [_]f32{ 0, 0, 0, 0 },

            .pNext = null,
            .flags = 0,
        };

        const dynamicStates = [_]c.VkDynamicState{
            c.enum_VkDynamicState.VK_DYNAMIC_STATE_VIEWPORT,
            c.enum_VkDynamicState.VK_DYNAMIC_STATE_SCISSOR,
        };

        self.dynamic_info = c.VkPipelineDynamicStateCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,

            .dynamicStateCount = dynamicStates.len,
            .pDynamicStates = &dynamicStates,

            .pNext = null,
            .flags = 0,
        };
    }
};
