const std = @import("std");
const trait = std.meta.trait;
const math = std.math;

pub fn deg2rad(deg: var) @TypeOf(deg) {
    comptime const Type = @TypeOf(deg);
    if (comptime trait.is(.Float)(Type) or comptime trait.is(.ComptimeFloat)(Type)) {
        return deg * (math.pi / 180.0);
    } else {
        return deg *  @floatToInt(Type, (math.pi / 180.0));
    }
}

pub fn rad2deg(rad: var) @TypeOf(rad) {
    comptime const Type = @TypeOf(rad);
    if (comptime trait.is(.Float)(Type) or comptime trait.is(.ComptimeFloat)(Type)) {
        return rad * (180.0 / math.pi);
    } else {
        return rad *  @floatToInt(Type, (180.0 / math.pi));
    }
}

//Vector
const vec = @import("vec.zig");
pub const Vec2 = vec.Vec2;
pub const Vec3 = vec.Vec3;
pub const Vec4 = vec.Vec4;

//Matrix
const mat = @import("mat.zig");
pub const Mat22 = mat.Mat22;
pub const Mat33 = mat.Mat33;
pub const Mat44 = mat.Mat44;