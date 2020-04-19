const zm = @import("zetamath");

const c = @import("c2.zig");

pub const VkVertex2d = packed struct {
    const Self = @This();

    pos: zm.Vec2(f32),
    color: zm.Vec3(f32),

    pub fn new(pos: zm.Vec2(f32), color: zm.Vec3(f32)) Self {
        return Self{
            .pos = pos,
            .color = color,
        };
    }
};