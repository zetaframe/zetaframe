pub const zmath = @import("zetamath");
usingnamespace @import("zetarender");

const std = @import("std");

pub fn rtest() !void {
    try vulkan_backend();
    std.meta.refAllDecls(@This());
}

// test "window" {
//     var testWindow = windowing.Window.new("Window Test", windowing.Size{ .width = 800, .height = 600 }, .None);
//     try testWindow.init();
//     defer testWindow.deinit();

//     std.time.sleep(1 * std.time.ns_per_s);
// }

fn vulkan_backend() !void {
    var testWindow = windowing.Window.new("Vulkan Test", windowing.Size{ .width = 1280, .height = 720 }, .Vulkan);
    try testWindow.init();
    defer testWindow.deinit();

    var vert = try backend.Shader.init(std.heap.page_allocator, "render/test/shaders/vulkan/vert.spv");
    var frag = try backend.Shader.init(std.heap.page_allocator, "render/test/shaders/vulkan/frag.spv");

    var swapchain = backend.vulkan.Swapchain.new();
    var renderpass = backend.vulkan.RenderPass.new();
    var pipeline = backend.vulkan.Pipeline.new(vert, frag);

    var vertex1 = objects.VkVertex2d.new(zmath.Vec2(f32).new(-0.5,- 0.5), zmath.Vec3(f32).new(1.0, 0.0, 0.0));
    var vertex2 = objects.VkVertex2d.new(zmath.Vec2(f32).new(0.5, -0.5), zmath.Vec3(f32).new(0.0, 1.0, 0.0));
    var vertex3 = objects.VkVertex2d.new(zmath.Vec2(f32).new(0.5, 0.5), zmath.Vec3(f32).new(0.0, 0.0, 1.0));
    var vertex4 = objects.VkVertex2d.new(zmath.Vec2(f32).new(-0.5, 0.5), zmath.Vec3(f32).new(1.0, 1.0, 1.0));
    var vertexBuffer = backend.vulkan.buffer.StagedBuffer(objects.VkVertex2d, .Vertex).new(&[_]objects.VkVertex2d{vertex1, vertex2, vertex3, vertex4});

    var indices = [_]u16{0, 1, 2, 2, 3, 0};
    var indexBuffer = backend.vulkan.buffer.StagedBuffer(u16, .Index).new(&indices);

    var command = backend.vulkan.Command.new(&vertexBuffer.buf, &indexBuffer.buf);

    var rendercore = backend.vulkan.RenderCore.new(swapchain, renderpass, pipeline, command);

    var vkbackend = backend.vulkan.VkBackend.new(std.heap.c_allocator, "Vulkan Test", &testWindow, rendercore);
    try vkbackend.init();
    defer vkbackend.deinit();

    while(testWindow.isRunning()) {
        testWindow.update();
        try vkbackend.render();
    }
}

// test "opengl backend" {
//     var testWindow = windowing.Window.new("OpenGL Test", windowing.Size{ .width = 800, .height = 600 }, .OpenGL);
//     try testWindow.init();
//     defer testWindow.deinit();

//     //var vert = try backend.Shader.init(std.heap.page_allocator, "test/shaders/opengl/vert.spv");
//     //var frag = try backend.Shader.init(std.heap.page_allocator, "test/shaders/opengl/frag.spv");

//     testWindow.update();
//     testWindow.update();

//     std.time.sleep(1 * std.time.ns_per_s);
// }
