const std = @import("std");
const math = std.math;
const trait = std.meta.trait;

pub fn Vec2(comptime T: type) type {
    if (!comptime trait.isNumber(T)) {
        @compileError("Vec2 type must be a number");
    }
    if (comptime trait.isUnsignedInt(T)) {
        @compileError("Vec2 type cannot be unsigned");
    }

    return packed struct {
        const Self = @This();

        x: T,
        y: T,

        pub const Up = Self{ .x = 0, .y = 1 };
        pub const Down = Self{ .x = 0, .y = -1 };
        pub const Left = Self{ .x = -1, .y = 0 };
        pub const Right = Self{ .x = 1, .y = 0 };
        pub const One = Self{ .x = 1, .y = 1 };
        pub const Zero = Self{ .x = 0, .y = 0 };

        pub fn new(x: T, y: T) Self {
            return Self{
                .x = x,
                .y = y,
            };
        }

        pub fn clone(self: *Self) Self {
            return Self{
                .x = self.x,
                .y = self.y,
            };
        }

        pub fn magnitude(self: *Self) T {
            return math.sqrt(self.magnitudeSqr());
        }

        pub fn magnitudeSqr(self: *Self) T {
            return (self.x * self.x) + (self.y * self.y);
        }

        pub fn add(self: *Self, other: *Self) Self {
            return Self{
                .x = self.x + other.x,
                .y = self.y + other.y,
            };
        }

        pub fn sub(self: *Self, other: *Self) Self {
            return Self{
                .x = self.x - other.x,
                .y = self.y - other.y,
            };
        }

        pub fn mulScalar(self: *Self, other: T) Self {
            return Self{
                .x = self.x * other,
                .y = self.y * other,
            };
        }

        pub fn mul(self: *Self, other: *Self) Self {
            return Self{
                .x = self.x * other.x,
                .y = self.y * other.y,
            };
        }

        pub fn divScalar(self: *Self, other: T) Self {
            return Self{
                .x = self.x / other,
                .y = self.y / other,
            };
        }

        pub fn div(self: *Self, other: *Self) Self {
            return Self{
                .x = self.x / other.x,
                .y = self.y / other.y,
            };
        }

        pub fn neg(self: *Self) Self {
            return Self{
                .x = -self.x,
                .y = -self.y,
            };
        }
    };
}

pub fn Vec3(comptime T: type) type {
    if (!comptime trait.isNumber(T)) {
        @compileError("Vec3 type must be a number");
    }
    if (comptime trait.isUnsignedInt(T)) {
        @compileError("Vec3 type cannot be unsigned");
    }

    return packed struct {
        const Self = @This();

        x: T,
        y: T,
        z: T,

        pub const Up = Self{ .x = 0, .y = 1, .z = 0 };
        pub const Down = Self{ .x = 0, .y = -1, .z = 0 };
        pub const Left = Self{ .x = -1, .y = 0, .z = 0 };
        pub const Right = Self{ .x = 1, .y = 0, .z = 0 };
        pub const Forward = Self{ .x = 0, .y = 0, .z = -1 };
        pub const Back = Self{ .x = 0, .y = 0, .z = 1 };
        pub const One = Self{ .x = 1, .y = 1, .z = 1 };
        pub const Zero = Self{ .x = 0, .y = 0, .z = 0 };

        pub fn new(x: T, y: T, z: T) Self {
            return Self{
                .x = x,
                .y = y,
                .z = z,
            };
        }

        pub fn newFromVec2(other: Vec2) Self {
            return Self{
                .x = other.x,
                .y = other.y,
                .z = 0,
            };
        }

        pub fn clone(self: *Self) Self {
            return Self{
                .x = self.x,
                .y = self.y,
                .z = self.z,
            };
        }

        pub fn magnitude(self: *Self) T {
            return math.sqrt(self.magnitudeSqr());
        }

        pub fn magnitudeSqr(self: *Self) T {
            return (self.x * self.x) + (self.y * self.y) + (self.z * self.z);
        }

        pub fn add(self: *Self, other: *Self) Self {
            return Self{
                .x = self.x + other.x,
                .y = self.y + other.y,
                .z = self.z + other.z,
            };
        }

        pub fn sub(self: *Self, other: *Self) Self {
            return Self{
                .x = self.x - other.x,
                .y = self.y - other.y,
                .z = self.z - other.z,
            };
        }

        pub fn mulScalar(self: *Self, other: T) Self {
            return Self{
                .x = self.x * other,
                .y = self.y * other,
                .z = self.z * other,
            };
        }

        pub fn mul(self: *Self, other: *Self) Self {
            return Self{
                .x = self.x * other.x,
                .y = self.y * other.y,
                .z = self.z * other.z,
            };
        }

        pub fn divScalar(self: *Self, other: T) Self {
            return Self{
                .x = self.x / other,
                .y = self.y / other,
                .z = self.z / other,
            };
        }

        pub fn div(self: *Self, other: *Self) Self {
            return Self{
                .x = self.x / other.x,
                .y = self.y / other.y,
                .z = self.z / other.z,
            };
        }

        pub fn neg(self: *Self) Self {
            return Self{
                .x = -self.x,
                .y = -self.y,
                .z = -self.z,
            };
        }
    };
}

pub fn Vec4(comptime T: type) type {
    if (!comptime trait.isNumber(T)) {
        @compileError("Vec4 type must be a number");
    }
    if (comptime trait.isUnsignedInt(T)) {
        @compileError("Vec4 type cannot be unsigned");
    }

    return packed struct {
        const Self = @This();

        x: T,
        y: T,
        z: T,
        w: T,

        pub const Up = Self{ .x = 0, .y = 1, .z = 0, .w = 0 };
        pub const Down = Self{ .x = 0, .y = -1, .z = 0, .w = 0 };
        pub const Left = Self{ .x = -1, .y = 0, .z = 0, .w = 0 };
        pub const Right = Self{ .x = 1, .y = 0, .z = 0, .w = 0 };
        pub const Forward = Self{ .x = 0, .y = 0, .z = -1, .w = 0 };
        pub const Back = Self{ .x = 0, .y = 0, .z = 1, .w = 0 };
        pub const In = Self{ .x = 0, .y = 0, .z = 0, .w = -1 };
        pub const Out = Self{ .x = 0, .y = 0, .z = 0, .w = 1 };
        pub const One = Self{ .x = 1, .y = 1, .z = 1, .w = 1 };
        pub const Zero = Self{ .x = 0, .y = 0, .z = 0, .w = 0 };

        pub fn new(x: T, y: T, z: T, w: T) Self {
            return Self{
                .x = x,
                .y = y,
                .z = z,
                .w = w,
            };
        }

        pub fn newFromVec2(other: Vec2) Self {
            return Self{
                .x = other.x,
                .y = other.y,
                .z = 0,
                .w = 0,
            };
        }

        pub fn newFromVec3(other: Vec3) Self {
            return Self{
                .x = other.x,
                .y = other.y,
                .z = other.z,
                .w = 0,
            };
        }

        pub fn clone(self: *Self) Self {
            return Self{
                .x = self.x,
                .y = self.y,
                .z = self.z,
                .w = self.w,
            };
        }

        pub fn magnitude(self: *Self) T {
            return math.sqrt(self.magnitudeSqr());
        }

        pub fn magnitudeSqr(self: *Self) T {
            return (self.x * self.x) + (self.y * self.y) + (self.z * self.z) + (self.w * self.w);
        }

        pub fn add(self: *Self, other: *Self) Self {
            return Self{
                .x = self.x + other.x,
                .y = self.y + other.y,
                .z = self.z + other.z,
                .w = self.w + other.w,
            };
        }

        pub fn sub(self: *Self, other: *Self) Self {
            return Self{
                .x = self.x - other.x,
                .y = self.y - other.y,
                .z = self.z - other.z,
                .w = self.w - other.w,
            };
        }

        pub fn mulScalar(self: *Self, other: T) Self {
            return Self{
                .x = self.x * other,
                .y = self.y * other,
                .z = self.z * other,
                .w = self.w * other,
            };
        }

        pub fn mul(self: *Self, other: *Self) Self {
            return Self{
                .x = self.x * other.x,
                .y = self.y * other.y,
                .z = self.z * other.z,
                .w = self.w * other.w,
            };
        }

        pub fn divScalar(self: *Self, other: T) Self {
            return Self{
                .x = self.x / other,
                .y = self.y / other,
                .z = self.z / other,
                .w = self.w / other,
            };
        }

        pub fn div(self: *Self, other: *Self) Self {
            return Self{
                .x = self.x / other.x,
                .y = self.y / other.y,
                .z = self.z / other.z,
                .w = self.w / other.w,
            };
        }

        pub fn neg(self: *Self) Self {
            return Self{
                .x = -self.x,
                .y = -self.y,
                .z = -self.z,
                .w = -self.w,
            };
        }
    };
}
