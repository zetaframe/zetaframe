pub const zmath = @import("zetamath");
usingnamespace @import("zetarender");

const std = @import("std");

pub fn rtest() !void {
    try vulkan_backend();
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

    var vert = try backend.Shader.init(std.heap.page_allocator, "/home/woze/projects/zig/gamedev/zetaframe/render/test/shaders/vulkan/vert.spv");
    var frag = try backend.Shader.init(std.heap.page_allocator, "/home/woze/projects/zig/gamedev/zetaframe/render/test/shaders/vulkan/frag.spv");

    var swapchain = backend.vulkan.Swapchain.new();
    var renderpass = backend.vulkan.RenderPass.new();
    var pipeline = backend.vulkan.Pipeline.new(vert, frag);
    var command = backend.vulkan.Command.new();

    var rendercore = backend.vulkan.RenderCore.new(swapchain, renderpass, pipeline, command);

    var vertext = vertex.VkVertex2d.new(zmath.Vec2(f32).Zero, zmath.Vec3(f32).One);

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
