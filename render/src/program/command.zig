const std = @import("std");
const Allocator = std.mem.Allocator;

const vk = @import("../include/vk.zig");

const Render = @import("../lib.zig").Render;
const Context = @import("../backend/context.zig").Context;
const Framebuffer = @import("../backend/framebuffer.zig").Framebuffer;

pub const IObject = struct {
    executeFn: fn (self: *const IObject, context: *const Context, cb: vk.CommandBuffer, fb: Framebuffer) anyerror!void,

    pub fn execute(self: *const IObject, context: *const Context, cb: vk.CommandBuffer, fb: Framebuffer) !void {
        try self.executeFn(self, context, cb, fb);
    }
};
