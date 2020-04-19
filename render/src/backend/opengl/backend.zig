const std = @import("std");

const Allocator = std.mem.Allocator;

const testing = std.testing;
const panic = std.debug.panic;

const windowing = @import("../../windowing.zig");
const backend = @import("../backend.zig");

const c = @import("../../c2.zig");

pub const GLError = enum{
    
}

pub const GLBackend = struct {
    
}