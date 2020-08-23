const zm = @import("zetamath");
usingnamespace @import("zetarender");

const std = @import("std");

test "shader" {
    std.debug.print("\n", .{});
    var shader = try backend.Shader.init(std.heap.c_allocator, "render/test/shaders/vert.spv");
    defer shader.deinit();
}

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

test "render" {
    std.debug.print("\n", .{});

    var testWindow = windowing.Window.new("Vulkan Test", .{ .width = 1280, .height = 720 });
    try testWindow.init();
    defer testWindow.deinit();

    var render = Render.new(std.heap.c_allocator, &testWindow);
    try render.init();
    defer render.deinit();

    const pipelinestate1 = program.pipeline.State(.{
        .render_pass = .{
            .attachments = &[_]program.renderpass.Attachment{},
            .subpasses = &[_]program.renderpass.SubPass{},
        },
        .layout = .{
            .set_layouts = &[_]program.descriptor.SetLayout{},
        },

        .topology = .triangle_list,
        .primitive_restart = false,

        .shader_stages = &[_]program.pipeline.ShaderStage{
            .{
                .stage = .{ .vertex_bit = true },
                .shader = .{ .path = "render/test/shaders/vert.spv" },
            },
            .{
                .stage = .{ .fragment_bit = true },
                .shader = .{ .path = "render/test/shaders/frag.spv" },
            },
        },

        .vertex_input_state = .{
            .input_rate = .vertex,
            .bindings = &[_]?type{Vertex},
        },
        .rasterizer_state = .{},
        .multisample_state = null,
        .depth_stencil_state = null,
        .color_blend_state = .{},
    }){};

    const simple_program = program.Program(.{
        program.Pass{
            .pipeline_state = &pipelinestate1.state,
        },
    }).init();

    try simple_program.execute();
}
