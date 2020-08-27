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

const SimplePipeline = program.pipeline.State(.{
    .render_pass = .{
        .attachments = &[_]program.renderpass.Attachment{.{
            .format = .r8g8b8a8_unorm,

            .samples = .{ .@"1_bit" = true },

            .load_op = .clear,
            .store_op = .store,

            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,

            .initial_layout = .@"undefined",
            .final_layout = .present_src_khr,
        }},
        .subpasses = &[_]program.renderpass.SubPass{.{
            .bind_point = .graphics,
            .color_attachments = &[_]program.renderpass.SubPass.Dependency{.{
                .index = 0,
                .layout = .color_attachment_optimal,
            }},
            .resolve_attachments = &[_]program.renderpass.SubPass.Dependency{},
        }},
    },
    .layout = .{
        .set_layouts = &[_]program.descriptor.SetLayout{},
    },

    .shader_stages = &[_]program.pipeline.ShaderStage{
        .{
            .stage = .{ .vertex_bit = true },
            .shader = .{ .path = "render/test/shaders/vert.spv" },
            .entrypoint = "main",
        },
        .{
            .stage = .{ .fragment_bit = true },
            .shader = .{ .path = "render/test/shaders/frag.spv" },
            .entrypoint = "main",
        },
    },

    .vertex_input_state = .{
        .input_rate = .vertex,
        .bindings = &[_]type{Vertex},
    },
    .input_assembly_state = .{
        .topology = .triangle_list,
        .primitive_restart = false,
    },
    .rasterizer_state = .{
        .cull_mode = .{ .back_bit = true },
        .front_face = .clockwise,
        .polygon_mode = .fill,
    },
    .multisample_state = null,
    .depth_stencil_state = null,
    .color_blend_state = .{},
});

test "render" {
    std.debug.print("\n", .{});

    var testWindow = windowing.Window.new("Vulkan Test", .{ .width = 1280, .height = 720 });
    try testWindow.init();
    defer testWindow.deinit();

    var render = Render.new(std.heap.c_allocator, &testWindow);
    try render.init();
    defer render.deinit();

    const simple_pipeline = try SimplePipeline.build(&render.backend.context);

    const simple_program = program.Program{
        .steps = &[_]program.Step{
            program.Step{
                .pipeline_state = &simple_pipeline.state,
            },
        },
    };

    try simple_program.execute();

    while (testWindow.isRunning()) {
        testWindow.update();
    }
}
