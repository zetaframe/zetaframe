const std = @import("std");
const zm = @import("zetamath");
usingnamespace @import("zetarender");

const vert_shader = @alignCast(@alignOf(u32), @embedFile("shaders/vert.spv"));
const frag_shader = @alignCast(@alignOf(u32), @embedFile("shaders/frag.spv"));

const zetarender_validation: bool = false;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    var allocator = &gpa.allocator;

    const GlobalData = packed struct {
        proj: zm.Mat44f align(16),
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

    var simple_material = Material.new(.{
        .vertex = try backend.Shader.initBytes(allocator, vert_shader),
        .fragment = try backend.Shader.initBytes(allocator, frag_shader),
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

    var vertex1 = Vertex.new(zm.Vec2f.new(-0.5, -0.5), zm.Vec3f.new(1.0, 0.0, 0.0));
    var vertex2 = Vertex.new(zm.Vec2f.new(0.5, -0.5), zm.Vec3f.new(0.0, 1.0, 0.0));
    var vertex3 = Vertex.new(zm.Vec2f.new(0.5, 0.5), zm.Vec3f.new(0.0, 0.0, 1.0));
    var vertex4 = Vertex.new(zm.Vec2f.new(-0.5, 0.5), zm.Vec3f.new(0.0, 0.0, 0.0));
    var vertexBuffer = backend.buffer.DirectBuffer(Vertex, .Vertex).new(&[_]Vertex{ vertex1, vertex2, vertex3, vertex4 });

    var indices = [_]u16{ 0, 1, 2, 2, 3, 0 };
    var indexBuffer = backend.buffer.DirectBuffer(u16, .Index).new(&indices);

    var swapchain = backend.Swapchain.new();
    var renderPass = backend.RenderPass.new();

    var vbackend = backend.Backend.new(allocator, &testWindow, swapchain, renderPass, .{ .in_flight_frames = 2 });
    try vbackend.init();

    try simple_material.init(allocator, &vbackend.context, &vbackend.render_pass, &vbackend.swapchain);

    var command0 = backend.command.IndexedDrawCommandBuffer.new(&vertexBuffer.buf, &indexBuffer.buf, &simple_material.pipeline, &vbackend.render_pass);
    try command0.command.init(allocator, &vbackend.vallocator, &vbackend.context);

    const ns_per_frame = 1000000000 / 64;

    var timer = std.time.Timer.start() catch unreachable;
    var last = @intToFloat(f64, timer.read());
    var fps: f64 = 0;
    var counter: f32 = 0;
    while (testWindow.isRunning()) {
        counter += 0.01;

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

        const now = @intToFloat(f64, timer.read());
        const fps2 = 1 / ((now - last) / 1000000000);
        fps = (fps * 0.99) + (fps2 * (1.0 - 0.99));
        last = now;

        std.debug.print("{d}\n", .{fps});
    }

    // Must call this first to ensure no frames are being rendered
    vbackend.deinitFrames();

    command0.command.deinit();
    simple_material.deinit();
    // uniform.deinit();

    vbackend.deinit();
    testWindow.deinit();
}
