const std = @import("std");

const vk = @import("../include/vk.zig");

const Context = @import("../backend/context.zig").Context;
const Framebuffer = @import("../backend/framebuffer.zig").Framebuffer;

pub const Step = @import("step.zig").Step;
pub const renderpass = @import("renderpass.zig");
pub const pipeline = @import("pipeline.zig");
pub const descriptor = @import("descriptor.zig");
pub const command = @import("command.zig");

pub const Program = struct {
    context: *const Context,

    steps: []const Step,

    pub fn build(context: *const Context, steps: []const Step) Program {
        if (steps[0] != .RenderPass) std.debug.panic("steps does not start with a renderpass!", .{});
        return Program{
            .context = context,

            .steps = steps,
        };
    }

    pub fn execute(self: *const Program, cb: vk.CommandBuffer, fb: Framebuffer) !void {
        // begin
        try self.context.vkd.beginCommandBuffer(cb, .{
            .flags = .{},
            .p_inheritance_info = null,
        });

        // dynamic states
        const viewport = vk.Viewport{
            .x = 0.0,
            .y = 0.0,
            .width = @intToFloat(f32, fb.size.width),
            .height = @intToFloat(f32, fb.size.height),
            .min_depth = 0.0,
            .max_depth = 1.0,
        };

        const scissor = vk.Rect2D{
            .offset = vk.Offset2D{ .x = 0, .y = 0 },
            .extent = fb.size,
        };

        self.context.vkd.cmdSetViewport(cb, 0, 1, @ptrCast([*]const vk.Viewport, &viewport));
        self.context.vkd.cmdSetScissor(cb, 0, 1, @ptrCast([*]const vk.Rect2D, &scissor));

        // execute
        for (self.steps) |step| {
            try switch (step) {
                .RenderPass => |r| r.execute(cb, fb),
                .Pipeline => |p| p.execute(cb, fb),
                .Command => |c| c.execute(self.context, cb, fb),
            };
        }

        // executePost
        var spets = try self.context.allocator.dupe(Step, self.steps);
        defer self.context.allocator.free(spets);
        std.mem.reverse(Step, spets);
        for (spets) |step| {
            try switch (step) {
                .RenderPass => |r| r.executePost(cb, fb),
                else => {},
            };
        }

        // end
        try self.context.vkd.endCommandBuffer(cb);
    }
};
