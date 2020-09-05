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
            .backend = backend.Backend.new(allocator, window, backend.Swapchain.new()),
        };
    }

    pub fn init(self: *Self) !void {
        try self.backend.init();
    }

    pub fn deinit(self: *Self) void {
        self.backend.deinit();
    }

    pub fn stop(self: *Self) void {
        self.backend.deinitFrames();
    }

    pub fn present(self: *Self, prog: *const program.Program) !void {
        try self.backend.present(prog);
    }

    // Program Builder

    pub fn buildProgram(self: *Self, steps: []const program.Step) program.Program {
        return program.Program.build(&self.backend.context, steps);
    }
};
