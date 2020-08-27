const zm = @import("zetamath");
usingnamespace @import("zetarender");

const std = @import("std");

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

const SimpleRenderPass = program.renderpass.Object(.{
    .clear_value = .{ .color = .{ .float_32 = [4]f32{ 1.0, 0.0, 0.0, 1.0 } } },
    .attachments = &[_]program.renderpass.Attachment{.{
        .format = null,

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
        // .resolve_attachments = &[_]program.renderpass.SubPass.Dependency{},
    }},
});

const SimplePipeline = program.pipeline.Object(.{
    .kind = .graphics,

    .render_pass = SimpleRenderPass,
    .layout = .{
        .set_layouts = &[_]program.descriptor.SetLayout{.{
            .bindings = &[_]program.descriptor.Binding{.{
                .name = "test",
                .kind = .uniform_buffer,
                .count = 1,
                .stages = .{ .vertex_bit = true, .fragment_bit = true },
            }},
        }},
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
    .color_blend_state = .{
        .attachments = &[_]program.pipeline.ColorBlendState.Attachment{
            .{
                .enable_blending = false,

                .color_blend_src = .zero,
                .color_blend_dst = .zero,
                .color_blend_op = .add,

                .alpha_blend_src = .zero,
                .alpha_blend_dst = .zero,
                .alpha_blend_op = .add,

                .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
            },
        },
    },
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    var allocator = &gpa.allocator;

    var testWindow = windowing.Window.new("Vulkan Test", .{ .width = 1280, .height = 720 });
    try testWindow.init();
    defer testWindow.deinit();

    var render = Render.new(allocator, &testWindow);
    try render.init();
    defer render.deinit();

    const simple_render_pass = try SimpleRenderPass.build(&render);
    defer simple_render_pass.deinit();

    const simple_pipeline = try SimplePipeline.build(&render, simple_render_pass);
    defer simple_pipeline.deinit();

    const simple_program = program.Program.build(&render.backend.context, &[_]program.Step{
        .{ .RenderPass = &simple_render_pass.base },
        .{ .Pipeline = &simple_pipeline.base },
    });

    while (testWindow.isRunning()) {
        testWindow.update();

        try render.backend.present(&simple_program);
    }

    render.stop();
}
