const std = @import("std");
const zm = @import("zetamath");
usingnamespace @import("zetarender");

const vert_shader = @alignCast(@alignOf(u32), @embedFile("shaders/vert.spv"));
const frag_shader = @alignCast(@alignOf(u32), @embedFile("shaders/frag.spv"));

pub fn main() !void {
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
            .vertex = try backend.Shader.initData(vert_shader),
            .fragment = try backend.Shader.initData(frag_shader),
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

    var swapchain = backend.Swapchain.new();
    var renderPass = backend.RenderPass.new();
    var command = backend.Command.new(&vertexBuffer.buf, &indexBuffer.buf);

    var vbackend = backend.Backend.new(std.heap.c_allocator, &testWindow, swapchain, renderPass);
    try vbackend.init();
    defer vbackend.deinit();

    try simple_material.init(std.heap.c_allocator, &vbackend.context, &vbackend.render_pass, &vbackend.swapchain);
    defer simple_material.deinit();

    var framebuffers = try std.heap.c_allocator.alloc(backend.Framebuffer, vbackend.swapchain.imageviews.len);
    defer std.heap.c_allocator.free(framebuffers);

    for (framebuffers) |*fb, i| {
        fb.* = try backend.Framebuffer.init(&vbackend.context, &[_]backend.ImageView{vbackend.swapchain.imageviews[i]}, &vbackend.render_pass, &vbackend.swapchain);
    }
    defer {
        for (framebuffers) |framebuffer| {
            framebuffer.deinit();
        }
    }

    try command.init(std.heap.c_allocator, &vbackend.vallocator, &vbackend.context, &vbackend.render_pass, &simple_material.pipeline, vbackend.swapchain.extent, framebuffers);
    defer command.deinit();

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

        try vbackend.submit(&command);

        //std.log.info(.example, "fps: {d}\n", .{1 / (@intToFloat(f64, timer.lap()) / 1000000000)});
    }
}