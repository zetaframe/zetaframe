const coretests = @import("core/test/test.zig");
const mathtests = @import("math/test/test.zig");
const rendertests = @import("render/test/test.zig");

test "core 0" {
    try coretests.rtest();
}

test "math 0" {
    try mathtests.rtest();
}

test "render 1" {
    try rendertests.rtest();
}
