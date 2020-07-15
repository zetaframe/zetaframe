const zm = @import("zetamath");
usingnamespace @import("zetarender");

const std = @import("std");

test "shader" {
    std.debug.print("\n", .{});
    var shader = try backend.Shader.init(std.heap.c_allocator, "render/test/shaders/vert.spv");
    defer shader.deinit();
}

test "render" {
    std.debug.print("\n", .{});

    var testWindow = windowing.Window.new("Vulkan Test", .{ .width = 1280, .height = 720 });
    try testWindow.init();
    defer testWindow.deinit();

    var render = Render.new(std.heap.c_allocator, &testWindow);
    try render.init();
    defer render.deinit();
}