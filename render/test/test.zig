pub const zm = @import("zetamath");
usingnamespace @import("zetarender");

const std = @import("std");

pub fn rtest() !void {
    std.debug.warn("\n", .{});

    try vulkan_backend();
}

fn vulkan_backend() !void {
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

    var testWindow = windowing.Window.new("Vulkan Test", windowing.Size{ .width = 1280, .height = 720 });
    try testWindow.init();
    defer testWindow.deinit();

    var vert = try backend.Shader.init(std.heap.page_allocator, "render/test/shaders/vert.spv");
    var frag = try backend.Shader.init(std.heap.page_allocator, "render/test/shaders/frag.spv");

    var swapchain = backend.Swapchain.new();
    var renderpass = backend.RenderPass.new();
    const pipelineSettings = backend.Pipeline.Settings{
        .inputs = &[_]backend.Pipeline.Settings.Input{
            try backend.Pipeline.Settings.Input.init(Vertex, 0, std.heap.c_allocator),
        },
        .assembly = backend.Pipeline.Settings.Assembly{
            .topology = .TRIANGLE_LIST
        },
        .rasterizer = backend.Pipeline.Settings.Rasterizer{

        }
    };
    var pipeline = backend.Pipeline.new(pipelineSettings, vert, frag);

    var vertex1 = Vertex.new(zm.Vec2f.new(-0.5,- 0.5), zm.Vec3f.new(1.0, 0.0, 0.0));
    var vertex2 = Vertex.new(zm.Vec2f.new(0.5, -0.5), zm.Vec3f.new(0.0, 1.0, 0.0));
    var vertex3 = Vertex.new(zm.Vec2f.new(0.5, 0.5), zm.Vec3f.new(0.0, 0.0, 1.0));
    var vertex4 = Vertex.new(zm.Vec2f.new(-0.5, 0.5), zm.Vec3f.new(0.0, 0.0, 0.0));
    var vertexBuffer = backend.buffer.StagedBuffer(Vertex, .Vertex).new(&[_]Vertex{vertex1, vertex2, vertex3, vertex4});

    var indices = [_]u16{0, 1, 2, 2, 3, 0};
    var indexBuffer = backend.buffer.StagedBuffer(u16, .Index).new(&indices);

    var command = backend.Command.new(&vertexBuffer.buf, &indexBuffer.buf);

    var rendercore = backend.RenderCore.new(swapchain, renderpass, pipeline, command);

    var vkbackend = backend.VkBackend.new(std.heap.c_allocator, "Vulkan Test", &testWindow, rendercore);
    try vkbackend.init();
    defer vkbackend.deinit();

    while(testWindow.isRunning()) {
        testWindow.update();
        try vkbackend.render();
    }
}
