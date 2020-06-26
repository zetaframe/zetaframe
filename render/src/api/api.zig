const std = @import("std");
const Allocator = std.mem.Allocator;

const windowing = @import("../windowing.zig");

const vbackend = @import("../backend/backend.zig");
const Backend = vbackend.Backend;

const material = @import("material.zig");
pub const Material = material.Material;
pub const MaterialInstance = material.MaterialInstance;

pub const Api = struct {
    const Self = @This();
    allocator: *Allocator,

    window: *windowing.Window,
    backend: Backend,

    pub fn new(allocator: *Allocator, window: *windowing.Window) Self {
        var backend = vbackend.Backend.new(allocator, "zetaframe", window, vbackend.Swapchain.new(), vbackend.RenderPass.new());
        
        return Self{
            .allocator = allocator,

            .window = window,
            .backend = backend,
        };
    }

    pub fn init(self: *Self) !void {
        var backend_ptr = &self.backend;
        try @ptrCast(*Backend, backend_ptr).init();
    }

    pub fn deinit(self: *Self) void {
        var backend_ptr = &self.backend;
        @ptrCast(*Backend, backend_ptr).deinit();
    }
};