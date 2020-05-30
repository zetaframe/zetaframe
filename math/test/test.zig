usingnamespace @import("zetamath");

const std = @import("std");
const testing = std.testing;

pub fn rtest() !void {
    std.debug.warn("\n", .{});

    var vec3_1 = Vec3(f32).new(0, 0, 0);
    var vec3_2 = vec3_1.clone();

    vec3_1.x = 1;

    testing.expect(vec3_1.x == 1);
    testing.expect(vec3_2.x == 0);

    vec3_2.x = 2;

    var vec3_3 = vec3_1.add(vec3_2);
    testing.expect(vec3_3.x == 3);

    var mat22_1 = Mat22(f32).new(Vec2(f32).new(1, 3), Vec2(f32).new(2, 4));
    var mat22_2 = mat22_1.transpose();
    var mat22_3 = mat22_2.transpose();
    testing.expect(mat22_1.x.x == mat22_2.x.x);
    testing.expect(mat22_1.x.x == mat22_3.x.x);
    testing.expect(mat22_1.x.y == mat22_2.y.x);
    testing.expect(mat22_1.x.y == mat22_3.x.y);

    var mat22_4 = mat22_1.mul(mat22_1);
    testing.expect(mat22_4.x.x == 7);

    var rad = deg2rad(@as(u32, 360));
    var deg = rad2deg(@as(u32, 1));

    try all_types();
}

fn all_types() !void {
    var vec2 = Vec2(f32).new(0, 0);
    var vec3 = Vec3(f32).new(0, 0, 0);
    var vec4 = Vec4(f32).new(0, 0, 0, 0);

    var mat22 = Mat22(f32).Identity;
    var mat33 = Mat33(f32).Identity;
    var mat44 = Mat44(f32).Identity;
}
