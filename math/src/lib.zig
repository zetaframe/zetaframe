const std = @import("std");
const trait = std.meta.trait;
const math = std.math;

// Common Functions
/// Convert degrees to radians
pub fn deg2rad(deg: anytype) @TypeOf(deg) {
    comptime const Type = @TypeOf(deg);
    if (comptime trait.is(.Float)(Type) or comptime trait.is(.ComptimeFloat)(Type)) {
        return deg * (math.pi / 180.0);
    } else {
        return deg * @floatToInt(Type, (math.pi / 180.0));
    }
}

/// Convert radians to degrees
pub fn rad2deg(rad: anytype) @TypeOf(rad) {
    comptime const Type = @TypeOf(rad);
    if (comptime trait.is(.Float)(Type) or comptime trait.is(.ComptimeFloat)(Type)) {
        return rad * (180.0 / math.pi);
    } else {
        return rad * @floatToInt(Type, (180.0 / math.pi));
    }
}

// Vector
const vec = @import("vec.zig");
pub const Vec2 = vec.Vec2;
pub const Vec3 = vec.Vec3;
pub const Vec4 = vec.Vec4;

// Common Types
/// Vector2 f32
pub const Vec2f = Vec2(f32);
/// Vector3 f32
pub const Vec3f = Vec3(f32);
/// Vector4 f32
pub const Vec4f = Vec4(f32);

//Matrix
const mat = @import("mat.zig");
pub const Mat22 = mat.Mat22;
pub const Mat33 = mat.Mat33;
pub const Mat44 = mat.Mat44;

// Common Types
/// Mat22 f32
pub const Mat22f = Mat22(f32);
/// Mat33 f32
pub const Mat33f = Mat33(f32);
/// Mat44 f32
pub const Mat44f = Mat44(f32);
