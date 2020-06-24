const std = @import("std");
const math = std.math;
const trait = std.meta.trait;
const assert = std.debug.assert;

const vec = @import("vec.zig");
const Vec2 = vec.Vec2;
const Vec3 = vec.Vec3;
const Vec4 = vec.Vec4;

fn MatMixin(comptime Self: type, comptime VecType: type, comptime T: type) type {
    return struct {
        /// Clones the Matrix
        pub fn clone(self: *Self) Self {
            var result = Self.Zero;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                @field(result, field.name) = @field(self.*, field.name);
            }
            return result;
        }

        /// Gets the vector at specified index
        pub fn getIndex(self: *Self, comptime index: usize) VecType {
            assert(index < 4);
            return @field(self.*, @typeInfo(Self).Struct.fields[index].name);
        }

        /// Gets the vector at specified index as a ptr
        pub fn getIndexPtr(self: *Self, comptime index: usize) *VecType {
            assert(index < 4);
            return &@field(self.*, @typeInfo(Self).Struct.fields[index].name);
        }

        /// Sets the vector at specified index
        pub fn setIndex(self: *Self, comptime index: usize, value: VecType) void {
            assert(index < 4);
            @field(self.*, @typeInfo(Self).Struct.fields[index].name) = value;
        }

        /// Transposes between Col Major and Row Major
        pub fn transpose(self: Self) Self {
            var result = Self.Zero;
            inline for (@typeInfo(Self).Struct.fields) |field, i| {
                inline for (@typeInfo(VecType).Struct.fields) |vec_field, j| {
                    result.getIndexPtr(j).setIndex(i, @field(@field(self, field.name), vec_field.name));
                }
            }
            return result;
        }

        /// Add two matrices
        pub fn add(self: Self, other: Self) Self {
            var result = Self.Zero;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                @field(result, field.name) = @field(self, field.name).add(@field(other, field.name));
            }
            return result;
        }

        /// Subtract two matrices
        pub fn sub(self: Self, other: Self) Self {
            var result = Self.Zero;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                @field(result, field.name) = @field(self, field.name).sub(@field(other, field.name));
            }
            return result;
        }

        /// Multiply two matrices
        pub fn mul(self: Self, other: Self) Self {
            var result = Self.Zero;
            var selfTransposed = self.transpose();
            inline for (@typeInfo(Self).Struct.fields) |self_field| {
                inline for (@typeInfo(Self).Struct.fields) |other_field| {
                    @field(@field(result, self_field.name), other_field.name) = @field(selfTransposed, self_field.name).dot(@field(other, other_field.name));
                }
            }
            return result;
        }

        /// Multiply a matrix by a scalar
        pub fn mulScalar(self: Self, other: T) Self {
            var result = Self.Zero;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                @field(result, field.name) = @field(self, field.name).mulScalar(other);
            }
            return result;
        }

        /// Divide a matrix by a scalar
        pub fn divScalar(self: Self, other: T) Self {
            var result = Self.Zero;
            inline for (@typeInfo(Self).Struct.fields) |field| {
                @field(result, field.name) = @field(self, field.name).divScalar(other);
            }
            return result;
        }
    };
}

/// 2x2 column major matrix
///
///  xy
/// x00
/// y00
pub fn Mat22(comptime T: type) type {
    if (!comptime trait.isNumber(T)) {
        @compileError("Mat22 type must be a number");
    }
    if (comptime trait.isUnsignedInt(T)) {
        @compileError("Mat22 type cannot be unsigned");
    }

    return extern struct {
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

        usingnamespace MatMixin(Self, Vec2(T), T);

        pub fn new(x: Vec2(T), y: Vec2(T)) Self {
            return Self{
                .x = x,
                .y = y,
            };
        }
    };
}

/// 3x3 column major matrix
///
///  xyz
/// x000
/// y000
/// z000
pub fn Mat33(comptime T: type) type {
    if (!comptime trait.isNumber(T)) {
        @compileError("Mat33 type must be a number");
    }
    if (comptime trait.isUnsignedInt(T)) {
        @compileError("Mat33 type cannot be unsigned");
    }

    return extern struct {
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

        usingnamespace MatMixin(Self, Vec3(T), T);

        pub fn new(x: Vec3(T), y: Vec3(T), z: Vec3(T)) Self {
            return Self{
                .x = x,
                .y = y,
                .z = z,
            };
        }
    };
}

/// 4x4 column major matrix
///
///  xyzw
/// x0000
/// y0000
/// z0000
/// w0000
pub fn Mat44(comptime T: type) type {
    if (!comptime trait.isNumber(T)) {
        @compileError("Mat44 type must be a number");
    }
    if (comptime trait.isUnsignedInt(T)) {
        @compileError("Mat44 type cannot be unsigned");
    }

    return extern struct {
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

        usingnamespace MatMixin(Self, Vec4(T), T);

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
