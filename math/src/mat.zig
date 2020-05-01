const std = @import("std");
const math = std.math;
const trait = std.meta.trait;

const vec = @import("vec.zig");
const Vec2 = vec.Vec2;
const Vec3 = vec.Vec3;
const Vec4 = vec.Vec4;

fn MatMixin(comptime Self: type) type {
    comptime const MatType = @typeInfo(@typeInfo(Self).Struct.fields[0].field_type).Struct.fields[0].field_type;
    return struct {
        pub fn clone(self: *Self) Self {
            var result = Self.Zero;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                @field(result, field.name) = @field(self.*, field.name);
            }
            return result;
        }

        pub fn add(self: Self, other: Self) Self {
            var result = Self.Zero;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                @field(result, field.name) = @field(self, field.name).add(@field(other, field.name));
            }
            return result;
        }

        pub fn sub(self: Self, other: Self) Self {
            var result = Self.Zero;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                @field(result, field.name) = @field(self, field.name).sub(@field(other, field.name));
            }
            return result;
        }

        pub fn mulScalar(self: Self, other: MatType) Self {
            var result = Self.Zero;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                @field(result, field.name) = @field(self, field.name).mulScalar(other);
            }
            return result;
        }

        pub fn divScalar(self: Self, other: MatType) Self {
            var result = Self.Zero;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                @field(result, field.name) = @field(self, field.name).divScalar(other);
            }
            return result;
        }
    };
}

pub fn Mat22(comptime T: type) type {
    if (!comptime trait.isNumber(T)) {
        @compileError("Mat22 type must be a number");
    }
    if (comptime trait.isUnsignedInt(T)) {
        @compileError("Mat22 type cannot be unsigned");
    }

    return packed struct {
        const Self = @This();

        x: Vec2(T),
        y: Vec2(T),

        pub const Identity = Self{
            .x = Vec2(T).new(1.0, 0.0),
            .y = Vec2(T).new(0.0, 1.0),
        };
        pub const One = Self{
            .x = Vec2(T).One,
            .y = Vec2(T).One,
        };
        pub const Zero = Self{
            .x = Vec2(T).Zero,
            .y = Vec2(T).Zero,
        };

        usingnamespace MatMixin(Self);

        pub fn new(x: Vec2(T), y: Vec2(T)) Self {
            return Self{
                .x = x,
                .y = y,
            };
        }
    };
}

pub fn Mat33(comptime T: type) type {
    if (!comptime trait.isNumber(T)) {
        @compileError("Mat33 type must be a number");
    }
    if (comptime trait.isUnsignedInt(T)) {
        @compileError("Mat33 type cannot be unsigned");
    }

    return packed struct {
        const Self = @This();

        x: Vec3(T),
        y: Vec3(T),
        z: Vec3(T),

        pub const Identity = Self{
            .x = Vec3(T).new(1.0, 0.0, 0.0),
            .y = Vec3(T).new(0.0, 1.0, 0.0),
            .z = Vec3(T).new(0.0, 0.0, 1.0),
        };
        pub const One = Self{
            .x = Vec3(T).One,
            .y = Vec3(T).One,
            .x = Vec3(T).One,
        };
        pub const Zero = Self{
            .x = Vec3(T).Zero,
            .y = Vec3(T).Zero,
            .z = Vec3(T).Zero,
        };

        usingnamespace MatMixin(Self);

        pub fn new(x: Vec3(T), y: Vec3(T), z: Vec3(T)) Self {
            return Self{
                .x = x,
                .y = y,
                .z = z,
            };
        }
    };
}

pub fn Mat44(comptime T: type) type {
    if (!comptime trait.isNumber(T)) {
        @compileError("Mat44 type must be a number");
    }
    if (comptime trait.isUnsignedInt(T)) {
        @compileError("Mat44 type cannot be unsigned");
    }

    return packed struct {
        const Self = @This();

        x: Vec4(T),
        y: Vec4(T),
        z: Vec4(T),
        w: Vec4(T),

        pub const Identity = Self{  
            .x = Vec4(T).new(1.0, 0.0, 0.0, 0.0),
            .y = Vec4(T).new(0.0, 1.0, 0.0, 0.0),
            .z = Vec4(T).new(0.0, 0.0, 1.0, 0.0),
            .w = Vec4(T).new(0.0, 0.0, 0.0, 1.0),
        };
        pub const One = Self{
            .x = Vec4(T).One,
            .y = Vec4(T).One,
            .x = Vec4(T).One,
            .w = Vec4(T).One,
        };
        pub const Zero = Self{
            .x = Vec4(T).Zero,
            .y = Vec4(T).Zero,
            .z = Vec4(T).Zero,
            .w = Vec4(T).Zero,
        };

        usingnamespace MatMixin(Self);

        pub fn new(x: Vec4(T), y: Vec4(T), z: Vec4(T), w: Vec4(T)) Self {
            return Self{
                .x = x,
                .y = y,
                .z = z,
                .w = w,
            };
        }
    };
}
