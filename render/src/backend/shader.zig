const std = @import("std");

pub const Shader = struct {
    const Self = @This();
    allocator: *std.mem.Allocator,

    shader_code: []const u8,
    shader_bytes: []align(@alignOf(u32)) const u8,

    pub fn init(allocator: *std.mem.Allocator, filepath: []const u8) !Self {
        return Self{
            .allocator = allocator,

            .shader_code = try std.fs.cwd().readFileAlloc(allocator, filepath, std.math.maxInt(u32)),
            .shader_bytes = try std.fs.cwd().readFileAllocOptions(allocator, filepath, std.math.maxInt(u32), @alignOf(u32), null),
        };
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.shader_code);
        self.allocator.free(self.shader_bytes);
    }
};
