pub const windowing = @import("windowing.zig");
pub const backend = @import("backend/backend.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;

const material = @import("material.zig");
pub const Material = material.Material;
pub const MaterialInstance = material.MaterialInstance;

pub const program = @import("program/program.zig");

pub const Render = struct {
    const Self = @This();
    allocator: *Allocator,

    window: *windowing.Window,
    backend: backend.Backend,

    pub fn new(allocator: *Allocator, window: *windowing.Window) Self {
        return Self{
            .allocator = allocator,

            .window = window,
            .backend = backend.Backend.new(allocator, window, backend.Swapchain.new(), backend.RenderPass.new(), .{ .in_flight_frames = 2 }),
        };
    }

    pub fn init(self: *Self) !void {
        try self.backend.init();
    }

    pub fn deinit(self: *Self) void {
        self.backend.deinitFrames();
        self.backend.deinit();
    }

    pub fn present() !void {

    }
};
