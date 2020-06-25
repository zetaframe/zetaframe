pub const zm = @import("zetamath");
usingnamespace @import("zetarender");

const std = @import("std");

test "vulkan_backend" {
    std.debug.warn("\n", .{});

    const UniformBufferObject = packed struct {
        model: zm.Mat44f,
        view: zm.Mat44f,
        proj: zm.Mat44f,
    };

    const Vertex = packed struct {
        const Self = @This();

        pos: zm.Vec2f,
        color: zm.Vec3f,

        pub fn new(pos: zm.Vec2f, color: zm.Vec3f) Self {
            return Self{
                .pos = pos,
                .color = color,
            };
        }
    };

    var simple_material = api.Material.new(.{
        .shaders = .{
            .vertex = try backend.Shader.init(std.heap.page_allocator, "render/test/shaders/vert.spv"),
            .fragment = try backend.Shader.init(std.heap.page_allocator, "render/test/shaders/frag.spv"),
        },
    }, .{
        .inputs = &[_]backend.Pipeline.Settings.Input{
            backend.Pipeline.Settings.Input.generateFromType(Vertex, 0),
        },
        .assembly = .{ .topology = .TRIANGLE_LIST },
        .rasterizer = .{},
    });

    var testWindow = windowing.Window.new("Vulkan Test", windowing.Size{ .width = 1280, .height = 720 });
    try testWindow.init();
    defer testWindow.deinit();

    var vert = try backend.Shader.init(std.heap.page_allocator, "render/test/shaders/vert.spv");
    var frag = try backend.Shader.init(std.heap.page_allocator, "render/test/shaders/frag.spv");

    var vertex1 = Vertex.new(zm.Vec2f.new(-0.5, -0.5), zm.Vec3f.new(1.0, 0.0, 0.0));
    var vertex2 = Vertex.new(zm.Vec2f.new(0.5, -0.5), zm.Vec3f.new(0.0, 1.0, 0.0));
    var vertex3 = Vertex.new(zm.Vec2f.new(0.5, 0.5), zm.Vec3f.new(0.0, 0.0, 1.0));
    var vertex4 = Vertex.new(zm.Vec2f.new(-0.5, 0.5), zm.Vec3f.new(0.0, 0.0, 0.0));
    var vertexBuffer = backend.buffer.DirectBuffer(Vertex, .Vertex).new(&[_]Vertex{ vertex1, vertex2, vertex3, vertex4 });

    var indices = [_]u16{ 0, 1, 2, 2, 3, 0 };
    var indexBuffer = backend.buffer.StagedBuffer(u16, .Index).new(&indices);

    var swapchain = backend.Swapchain.new();
    var command = backend.Command.new(&vertexBuffer.buf, &indexBuffer.buf);

    var vbackend = backend.Backend.new(std.heap.c_allocator, "Vulkan Test", &testWindow, swapchain);
    try vbackend.init();
    defer vbackend.deinit();

    try simple_material.init(std.heap.c_allocator, &vbackend.gpu, &vbackend.swapchain);
    defer simple_material.deinit();

    var framebuffers = [_]backend.Framebuffer{
        try backend.Framebuffer.init(&vbackend.gpu, &[_]backend.ImageView{vbackend.swapchain.imageviews[0]}, &simple_material.render_pass, &vbackend.swapchain),
        try backend.Framebuffer.init(&vbackend.gpu, &[_]backend.ImageView{vbackend.swapchain.imageviews[1]}, &simple_material.render_pass, &vbackend.swapchain),
        try backend.Framebuffer.init(&vbackend.gpu, &[_]backend.ImageView{vbackend.swapchain.imageviews[2]}, &simple_material.render_pass, &vbackend.swapchain),
        try backend.Framebuffer.init(&vbackend.gpu, &[_]backend.ImageView{vbackend.swapchain.imageviews[3]}, &simple_material.render_pass, &vbackend.swapchain),
        try backend.Framebuffer.init(&vbackend.gpu, &[_]backend.ImageView{vbackend.swapchain.imageviews[4]}, &simple_material.render_pass, &vbackend.swapchain),
    };
    defer {
        for (framebuffers) |framebuffer| {
            framebuffer.deinit();
        }
    }

    try command.init(std.heap.c_allocator, &vbackend.vallocator, &vbackend.gpu, &simple_material.render_pass, &simple_material.pipeline, vbackend.swapchain.extent, &framebuffers);
    defer command.deinit();

    while (testWindow.isRunning()) {
        testWindow.update();
        vertex1.color.x = @mod((vertex1.color.x + 0.001), 1.0);
        vertex2.color.y = @mod((vertex1.color.x - 0.001), 1.0);
        vertex3.color.z = @mod((vertex1.color.x + 0.001), 1.0);
        vertex4.color.x = @mod((vertex1.color.x - 0.001), 1.0);
        try vertexBuffer.update(&[_]Vertex{ vertex1, vertex2, vertex3, vertex4 });
        try vbackend.submit(&command);
    }
}
