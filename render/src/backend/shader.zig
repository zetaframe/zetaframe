const std = @import("std");

pub const Shader = struct {
    pub const Stage = enum {
        Vertex,
        Fragment,
    };

    const Self = @This();
    allocator: *std.mem.Allocator,

    from_file: bool,
    shader_bytes: [:0]align(@alignOf(u32)) const u8,

    stage: Stage,

    pub fn init(allocator: *std.mem.Allocator, filepath: []const u8, stage: Stage) !Self {
        return Self{
            .allocator = allocator,

            .from_file = true,
            .shader_bytes = try std.fs.cwd().readFileAllocOptions(allocator, filepath, std.math.maxInt(u32), @alignOf(u32), 0),

            .stage = stage,
        };
    }

    pub fn initData(data: [:0]align(@alignOf(u32)) const u8, stage: Stage) !Self {
        return Self{
            .allocator = undefined,

            .from_file = false,
            .shader_bytes = data,

            .stage = stage,
        };
    }

    pub fn deinit(self: Self) void {
        if (self.from_file) self.allocator.free(self.shader_bytes);
    }
};
