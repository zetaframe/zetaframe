const std = @import("std");

const Allocator = std.mem.Allocator;

const windowing = @import("../windowing.zig");

const shader = @import("shader.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const vk = @import("../include/vk.zig");

const Context = @import("context.zig").Context;

pub const RenderPass = struct {
    const Self = @This();

    context: *Context,

    render_pass: vk.RenderPass,

    pub fn new() Self {
        return Self{
            .context = undefined,

            .render_pass = undefined,
        };
    }

    pub fn init(self: *Self, context: *Context, swapchainImageFormat: vk.Format) !void {
        self.context = context;

        try self.createRenderPass(swapchainImageFormat);
    }

    pub fn deinit(self: Self) void {
        self.context.vkd.destroyRenderPass(self.context.device, self.render_pass, null);
    }

    fn createRenderPass(self: *Self, swapchainImageFormat: vk.Format) !void {
        const colorAttachments = [_]vk.AttachmentDescription{vk.AttachmentDescription{
            .format = swapchainImageFormat,

            .samples = vk.SampleCountFlags{ .@"1_bit" = true },

            .load_op = .clear,
            .store_op = .store,

            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,

            .initial_layout = .@"undefined",
            .final_layout = .present_src_khr,

            .flags = .{},
        }};

        const colorAttachmentRefs = [_]vk.AttachmentReference{vk.AttachmentReference{
            .attachment = 0,

            .layout = .color_attachment_optimal,
        }};

        const subpasses = [_]vk.SubpassDescription{vk.SubpassDescription{
            .pipeline_bind_point = .graphics,

            .input_attachment_count = 0,
            .p_input_attachments = undefined,

            .color_attachment_count = colorAttachmentRefs.len,
            .p_color_attachments = &colorAttachmentRefs,

            .preserve_attachment_count = 0,
            .p_preserve_attachments = undefined,

            .p_resolve_attachments = undefined,
            .p_depth_stencil_attachment = undefined,

            .flags = .{},
        }};

        const dependencies = [_]vk.SubpassDependency{vk.SubpassDependency{
            .src_subpass = vk.SUBPASS_EXTERNAL,
            .src_stage_mask = vk.PipelineStageFlags{ .color_attachment_output_bit = true },
            .src_access_mask = undefined,

            .dst_subpass = 0,
            .dst_stage_mask = vk.PipelineStageFlags{ .color_attachment_output_bit = true },
            .dst_access_mask = vk.AccessFlags{ .color_attachment_write_bit = true },

            .dependency_flags = .{},
        }};

        const renderPassInfo = vk.RenderPassCreateInfo{
            .attachment_count = colorAttachments.len,
            .p_attachments = &colorAttachments,

            .subpass_count = subpasses.len,
            .p_subpasses = &subpasses,

            .dependency_count = dependencies.len,
            .p_dependencies = &dependencies,

            .flags = .{},
        };

        self.render_pass = try self.context.vkd.createRenderPass(self.context.device, renderPassInfo, null);
    }
};
