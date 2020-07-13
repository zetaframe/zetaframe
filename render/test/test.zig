const zm = @import("zetamath");
usingnamespace @import("zetarender");

const std = @import("std");

test "vulkan_backend" {
    std.debug.print("\n", .{});

    var allocator = std.heap.c_allocator;

    const UniformBufferObject = packed struct {
        model: zm.Mat44f,
        view: zm.Mat44f,
        proj: zm.Mat44f,
    };

    var uniform = backend.Uniform.new(UniformBufferObject, 0, .Vertex);

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
            .vertex = try backend.Shader.init(std.heap.c_allocator, "render/test/shaders/vert.spv", .Vertex),
            .fragment = try backend.Shader.init(std.heap.c_allocator, "render/test/shaders/frag.spv", .Fragment),
        },
    }, .{
        .inputs = &[_]backend.Pipeline.Settings.Input{
            backend.Pipeline.Settings.Input.generateFromType(Vertex, 0),
        },
        .assembly = .{
            .topology = .TriangleList,
        },
        .rasterizer = .{
            .cull_mode = .None,
            .front_face = .Clockwise,
        },
    });

    var testWindow = windowing.Window.new("Vulkan Test", .{ .width = 1280, .height = 720 });
    try testWindow.init();
    defer testWindow.deinit();

    var vertex1 = Vertex.new(zm.Vec2f.new(-0.5, -0.5), zm.Vec3f.new(1.0, 0.0, 0.0));
    var vertex2 = Vertex.new(zm.Vec2f.new(0.5, -0.5), zm.Vec3f.new(0.0, 1.0, 0.0));
    var vertex3 = Vertex.new(zm.Vec2f.new(0.5, 0.5), zm.Vec3f.new(0.0, 0.0, 1.0));
    var vertex4 = Vertex.new(zm.Vec2f.new(-0.5, 0.5), zm.Vec3f.new(0.0, 0.0, 0.0));
    var vertexBuffer = backend.buffer.DirectBuffer(Vertex, .Vertex).new(&[_]Vertex{ vertex1, vertex2, vertex3, vertex4 });

    var indices = [_]u16{ 0, 1, 2, 2, 3, 0 };
    var indexBuffer = backend.buffer.StagedBuffer(u16, .Index).new(&indices);

    var swapchain = backend.Swapchain.new();
    var renderPass = backend.RenderPass.new();

    var vbackend = backend.Backend.new(allocator, &testWindow, swapchain, renderPass, .{ .in_flight_frames = 2 });
    try vbackend.init();
    defer vbackend.deinit();

    try uniform.init(allocator, &vbackend.vallocator, &vbackend.context);
    defer uniform.deinit();

    try simple_material.init(allocator, &vbackend.context, &vbackend.render_pass, &vbackend.swapchain);
    defer simple_material.deinit();

    var command0 = backend.command.IndexedDrawCommandBuffer.new(&vertexBuffer.buf, &indexBuffer.buf, &simple_material.pipeline, &vbackend.render_pass);
    try command0.command.init(allocator, &vbackend.vallocator, &vbackend.context);
    defer command0.command.deinit();

    defer vbackend.deinitFrames();

    var timer = std.time.Timer.start() catch unreachable;
    var counter: f32 = 0;
    while (testWindow.isRunning()) {
        counter += 0.01;
        timer.reset();

        testWindow.update();

        vertex1.color.x = @mod(vertex1.color.x + 0.001, 1.0);
        vertex2.color.y = @mod(vertex1.color.x - 0.001, 1.0);
        vertex3.color.z = @mod(vertex1.color.x + 0.001, 1.0);
        vertex4.color.x = @mod(vertex1.color.x - 0.001, 1.0);
        vertex1.pos.x = @sin(counter);
        vertex1.pos.y = @cos(counter);
        vertex2.pos.x = @sin(-counter);
        vertex2.pos.y = @cos(counter);

        try vertexBuffer.update(&[_]Vertex{ vertex1, vertex2, vertex3, vertex4 });

        try vbackend.present(&command0.command);

        try vbackend.vallocator.gc();

        if (counter >= 4) break;
    }
}

test "api" {
    std.debug.print("\n", .{});

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
            .vertex = try backend.Shader.init(std.heap.c_allocator, "render/test/shaders/vert.spv", .Vertex),
            .fragment = try backend.Shader.init(std.heap.c_allocator, "render/test/shaders/frag.spv", .Fragment),
        },
    }, .{
        .inputs = &[_]backend.Pipeline.Settings.Input{
            backend.Pipeline.Settings.Input.generateFromType(Vertex, 0),
        },
        .assembly = .{
            .topology = .TriangleList,
        },
        .rasterizer = .{
            .cull_mode = .None,
            .front_face = .Clockwise,
        },
    });

    var testWindow = windowing.Window.new("Vulkan Test", .{ .width = 1280, .height = 720 });
    try testWindow.init();
    defer testWindow.deinit();

    var vertex1 = Vertex.new(zm.Vec2f.new(-0.5, -0.5), zm.Vec3f.new(1.0, 0.0, 0.0));
    var vertex2 = Vertex.new(zm.Vec2f.new(0.5, -0.5), zm.Vec3f.new(0.0, 1.0, 0.0));
    var vertex3 = Vertex.new(zm.Vec2f.new(0.5, 0.5), zm.Vec3f.new(0.0, 0.0, 1.0));
    var vertex4 = Vertex.new(zm.Vec2f.new(-0.5, 0.5), zm.Vec3f.new(0.0, 0.0, 0.0));
    var vertexBuffer = backend.buffer.StagedBuffer(Vertex, .Vertex).new(&[_]Vertex{ vertex1, vertex2, vertex3, vertex4 });

    var indices = [_]u16{ 0, 1, 2, 2, 3, 0 };
    var indexBuffer = backend.buffer.StagedBuffer(u16, .Index).new(&indices);

    var vapi = api.Api.new(std.heap.c_allocator, &testWindow);
    try vapi.init();
    defer vapi.deinit();

    var counter: f32 = 0;
    while (testWindow.isRunning()) {
        testWindow.update();
        counter += 0.001;
        if (counter > 500) {
            break;
        }
    }
}
