pub const zm = @import("zetamath");
usingnamespace @import("zetarender");

const std = @import("std");

pub fn rtest() !void {
    std.debug.warn("\n", .{});

    try vulkan_backend();
    std.meta.refAllDecls(@This());
}

// test "window" {
//     warn("\n", .{});

//     var testWindow = windowing.Window.new("Window Test", windowing.Size{ .width = 800, .height = 600 }, .None);
//     try testWindow.init();
//     defer testWindow.deinit();

//     std.time.sleep(1 * std.time.ns_per_s);
// }

fn vulkan_backend() !void {
    std.debug.warn("\n", .{});

    const UniformBufferObject = packed struct {
        model: zm.Mat44(f32),
        view: zm.Mat44(f32),
        proj: zm.Mat44(f32),
    };

    const Vertex = packed struct {
        const Self = @This();

        pos: zm.Vec2(f32),
        color: zm.Vec3(f32),

        pub fn new(pos: zm.Vec2(f32), color: zm.Vec3(f32)) Self {
            return Self{
                .pos = pos,
                .color = color,
            };
        }
    };

    var testWindow = windowing.Window.new("Vulkan Test", windowing.Size{ .width = 1280, .height = 720 }, .Vulkan);
    try testWindow.init();
    defer testWindow.deinit();

    var vert = try backend.Shader.init(std.heap.page_allocator, "render/test/shaders/vulkan/vert.spv");
    var frag = try backend.Shader.init(std.heap.page_allocator, "render/test/shaders/vulkan/frag.spv");

    var swapchain = backend.vulkan.Swapchain.new();
    var renderpass = backend.vulkan.RenderPass.new();
    const pipelineSettings = backend.vulkan.pipeline.Settings{
        .inputs = &[_]backend.vulkan.pipeline.Settings.Input{
            try backend.vulkan.pipeline.Settings.Input.init(Vertex, 0, std.heap.c_allocator),
        },
        .assembly = backend.vulkan.pipeline.Settings.Assembly{
            .topology = .TRIANGLE_LIST
        },
        .rasterizer = backend.vulkan.pipeline.Settings.Rasterizer{

        }
    };
    var pipeline = backend.vulkan.Pipeline.new(pipelineSettings, vert, frag);

    var vertex1 = Vertex.new(zm.Vec2(f32).new(-0.5,- 0.5), zm.Vec3(f32).new(1.0, 0.0, 0.0));
    var vertex2 = Vertex.new(zm.Vec2(f32).new(0.5, -0.5), zm.Vec3(f32).new(0.0, 1.0, 0.0));
    var vertex3 = Vertex.new(zm.Vec2(f32).new(0.5, 0.5), zm.Vec3(f32).new(0.0, 0.0, 1.0));
    var vertex4 = Vertex.new(zm.Vec2(f32).new(-0.5, 0.5), zm.Vec3(f32).new(0.0, 0.0, 0.0));
    var vertexBuffer = backend.vulkan.buffer.StagedBuffer(Vertex, .Vertex).new(&[_]Vertex{vertex1, vertex2, vertex3, vertex4});

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
//     warn("\n", .{});

//     var testWindow = windowing.Window.new("OpenGL Test", windowing.Size{ .width = 800, .height = 600 }, .OpenGL);
//     try testWindow.init();
//     defer testWindow.deinit();

//     //var vert = try backend.Shader.init(std.heap.page_allocator, "test/shaders/opengl/vert.spv");
//     //var frag = try backend.Shader.init(std.heap.page_allocator, "test/shaders/opengl/frag.spv");

//     testWindow.update();
//     testWindow.update();

//     std.time.sleep(1 * std.time.ns_per_s);
// }
