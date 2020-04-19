const coretests = @import("core/test/test.zig");
const mathtests = @import("math/test/test.zig");
const rendertests = @import("render/test/test.zig");

test "core" {
    try coretests.rtest();
}

test "math" {
    try mathtests.rtest();
}

test "render" {
    try rendertests.rtest();
}