const std = @import("std");
const Allocator = std.mem.Allocator;

const vk = @import("../include/vk.zig");

const Context = @import("../backend/context.zig").Context;
const Framebuffer = @import("../backend/framebuffer.zig").Framebuffer;

pub const IObject = struct {
    initFn: fn (self: *const IObject, context: *const Context) anyerror!void,
    deinitFn: fn (self: *const IObject) void,
    executeFn: fn (self: *const IObject, cb: vk.CommandBuffer, fb: Framebuffer) anyerror!void,

    pub fn init(self: *const IObject, context: *const Context) !void {
        try self.initFn(self, allocator, vallocator, context);
    }

    pub fn deinit(self: *const IObject) void {
        self.deinitFn(self);
    }

    pub fn execute(self: *const IObject, cb: vk.CommandBuffer, fb: Framebuffer) !void {
        try self.executeFn(self, cb, fb);
    }
};