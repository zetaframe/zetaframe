const std = @import("std");
const math = std.math;
const trait = std.meta.trait;
const assert = std.debug.assert;

fn VecMixin(comptime Self: type, comptime T: type) type {
    return struct {
        pub fn clone(self: *Self) Self {
            var result = Self.Zero;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                @field(result, field.name) = @field(self.*, field.name);
            }
            return result;
        }

        pub fn neg(self: Self) T {
            var result = Self.Zero;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                @field(result, field.name) = -@field(self, field.name);
            }
            return result;
        }

        pub fn getIndex(self: *Self, index: usize) T {
            assert(index < 4);
            return @field(self.*, @typeInfo(Self).Struct.fields[index].name);
        }

        pub fn setIndex(self: *Self, comptime index: usize, value: T) void {
            assert(index < 4);
            @field(self.*, @typeInfo(Self).Struct.fields[index].name) = value;
        }

        pub fn add(self: Self, other: Self) Self {
            var result = Self.Zero;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                @field(result, field.name) = @field(self, field.name) + @field(other, field.name);
            }
            return result;
        }

        pub fn sub(self: Self, other: Self) Self {
            var result = Self.Zero;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                @field(result, field.name) = @field(self, field.name) - @field(other, field.name);
            }
            return result;
        }

        pub fn mul(self: Self, other: Self) Self {
            var result = Self.Zero;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                @field(result, field.name) = @field(self, field.name) * @field(other, field.name);
            }
            return result;
        }

        pub fn mulScalar(self: Self, other: T) Self {
            var result = Self.Zero;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                @field(result, field.name) = @field(self, field.name) * other;
            }
            return result;
        }

        pub fn div(self: Self, other: Self) Self {
            var result = Self.Zero;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                @field(result, field.name) = @field(self, field.name) / @field(other, field.name);
            }
            return result;
        }

        pub fn divScalar(self: Self, other: T) Self {
            var result = Self.Zero;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                @field(result, field.name) = @field(self, field.name) / other;
            }
            return result;
        }

        pub fn mag(self: Self) T {
            return math.sqrt(self.magSqr());
        }

        pub fn magSqr(self: Self) T {
            var result: T = 0;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                result += @field(self, field.name) * @field(self, field.name);
            }
            return result;
        }

        pub fn dot(self: Self, other: Self) T {
            var result: T = 0;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                result += @field(self, field.name) * @field(other, field.name);
            }
            return result;
        }
    };
}

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

        usingnamespace VecMixin(Self, T);

        pub fn new(x: T, y: T) Self {
            return Self{
                .x = x,
                .y = y,
            };
        }

        pub fn newFromVec3(other: Vec3) Self {
            return Self{
                .x = other.x,
                .y = other.y,
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

        usingnamespace VecMixin(Self, T);

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

        pub fn newFromVec4(other: Vec4) Self {
            return Self{
                .x = other.x,
                .y = other.y,
                .z = other.z,
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

        usingnamespace VecMixin(Self, T);

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
    };
}
