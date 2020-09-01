const std = @import("std");
const Allocator = std.mem.Allocator;

const vk = @import("../include/vk.zig");

const Render = @import("../lib.zig").Render;
const Context = @import("../backend/context.zig").Context;
const Framebuffer = @import("../backend/framebuffer.zig").Framebuffer;

pub const IObject = struct {
    executeFn: fn (self: *const IObject, cb: vk.CommandBuffer, fb: Framebuffer) anyerror!void,
    executePostFn: fn (self: *const IObject, cb: vk.CommandBuffer, fb: Framebuffer) anyerror!void,
    renderpassFn: fn (self: *const IObject) vk.RenderPass,

    pub fn execute(self: *const IObject, cb: vk.CommandBuffer, fb: Framebuffer) !void {
        try self.executeFn(self, cb, fb);
    }

    pub fn executePost(self: *const IObject, cb: vk.CommandBuffer, fb: Framebuffer) !void {
        try self.executePostFn(self, cb, fb);
    }

    pub fn renderpass(self: *const IObject) vk.RenderPass {
        return self.renderpassFn(self);
    }
};

pub const State = struct {
    attachments: []const Attachment,
    subpasses: []const SubPass,

    /// Creates a new state with the specified overrides
    pub fn override(comptime self: *const State, comptime Override: anytype) State {
        comptime var new = State{
            .attachments = self.attachments,
            .subpasses = self.subpasses,
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
            .executePostFn = executePost,
            .renderpassFn = renderpass,
        },
        context: *const Context,

        clear_value: ?*const vk.ClearValue,

        render_pass: vk.RenderPass,

        pub fn build(render: *Render, clear_value: ?*const vk.ClearValue) !Self {
            const context = &render.backend.context;

            // create ColorAttachments
            var color_attachments: [state.attachments.len]vk.AttachmentDescription = undefined;
            for (state.attachments) |attachment, i| {
                color_attachments[i] = .{
                    .format = if (attachment.format) |f| f else render.backend.swapchain.image_format,
                    .samples = attachment.samples,

                    .load_op = attachment.load_op,
                    .store_op = attachment.store_op,

                    .stencil_load_op = attachment.stencil_load_op,
                    .stencil_store_op = attachment.stencil_store_op,

                    .initial_layout = attachment.initial_layout,
                    .final_layout = attachment.final_layout,

                    .flags = .{},
                };
            }

            // create Subpasses
            comptime var subpasses: [state.subpasses.len]vk.SubpassDescription = undefined;
            comptime for (state.subpasses) |subpass, i| {
                var color_refs: [subpass.color_attachments.len]vk.AttachmentReference = undefined;
                for (subpass.color_attachments) |attachment, j| {
                    color_refs[j] = vk.AttachmentReference{
                        .attachment = attachment.index,
                        .layout = attachment.layout,
                    };
                }

                subpasses[i] = vk.SubpassDescription{
                    .pipeline_bind_point = subpass.bind_point,

                    .input_attachment_count = 0,
                    .p_input_attachments = undefined,

                    .color_attachment_count = subpass.color_attachments.len,
                    .p_color_attachments = &color_refs,

                    .preserve_attachment_count = 0,
                    .p_preserve_attachments = undefined,

                    .p_resolve_attachments = undefined,
                    .p_depth_stencil_attachment = undefined,

                    .flags = .{},
                };
            };

            // create RenderPass
            const create_info = vk.RenderPassCreateInfo{
                .attachment_count = color_attachments.len,
                .p_attachments = &color_attachments,

                .subpass_count = subpasses.len,
                .p_subpasses = &subpasses,

                .dependency_count = 0,
                .p_dependencies = undefined,

                .flags = .{},
            };

            const render_pass = try context.vkd.createRenderPass(context.device, create_info, null);

            return Self{
                .context = context,

                .clear_value = clear_value,

                .render_pass = render_pass,
            };
        }

        pub fn deinit(self: Self) void {
            self.context.vkd.destroyRenderPass(self.context.device, self.render_pass, null);
        }

        pub fn execute(base: *const IObject, cb: vk.CommandBuffer, fb: Framebuffer) !void {
            const self = @fieldParentPtr(Self, "base", base);

            const clear_value = if (self.clear_value) |cv| cv else &vk.ClearValue{ .color = .{ .float_32 = [4]f32{ 0.0, 0.0, 0.0, 1.0 } } };

            self.context.vkd.cmdBeginRenderPass(cb, .{
                .render_pass = self.render_pass,

                .framebuffer = fb.framebuffer,

                .render_area = vk.Rect2D{
                    .offset = vk.Offset2D{ .x = 0, .y = 0 },
                    .extent = fb.size,
                },

                .clear_value_count = 1,
                .p_clear_values = @ptrCast([*]const vk.ClearValue, clear_value),
            }, .@"inline");
        }

        pub fn executePost(base: *const IObject, cb: vk.CommandBuffer, fb: Framebuffer) !void {
            const self = @fieldParentPtr(Self, "base", base);

            self.context.vkd.cmdEndRenderPass(cb);
        }

        pub fn renderpass(base: *const IObject) vk.RenderPass {
            return @fieldParentPtr(Self, "base", base).render_pass;
        }
    };
}

pub const Attachment = struct {
    /// if null will use swapchain format
    format: ?vk.Format,
    samples: vk.SampleCountFlags,

    load_op: vk.AttachmentLoadOp,
    store_op: vk.AttachmentStoreOp,

    stencil_load_op: vk.AttachmentLoadOp,
    stencil_store_op: vk.AttachmentStoreOp,

    initial_layout: vk.ImageLayout,
    final_layout: vk.ImageLayout,
};

pub const SubPass = struct {
    pub const Dependency = struct {
        index: usize,
        layout: vk.ImageLayout,
    };

    bind_point: vk.PipelineBindPoint,
    color_attachments: []const Dependency,
    // resolve_attachments: []const Dependency,
};
