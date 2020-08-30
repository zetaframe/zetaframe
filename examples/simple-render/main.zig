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

const vert_shader = @alignCast(@alignOf(u32), @embedFile("shaders/vert.spv"));
const frag_shader = @alignCast(@alignOf(u32), @embedFile("shaders/frag.spv"));

const SimplePipelineState = program.pipeline.State{
    .kind = .graphics,

    .render_pass = SimpleRenderPass,
    .layout = .{
        .set_layouts = &[_]program.descriptor.SetLayout{
            // .{
            //     .bindings = &[_]program.descriptor.Binding{.{
            //         .name = "test",
            //         .kind = .uniform_buffer,
            //         .count = 1,
            //         .stages = .{ .vertex_bit = true, .fragment_bit = true },
            //     }},
            // },
        },
    },

    .shader_stages = &[_]program.pipeline.ShaderStage{
        .{
            .stage = .{ .vertex_bit = true },
            .shader = .{ .bytes = vert_shader },
            .entrypoint = "main",
        },
        .{
            .stage = .{ .fragment_bit = true },
            .shader = .{ .bytes = frag_shader },
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
        .cull_mode = .{},
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
};
const SimplePipeline = program.pipeline.Object(SimplePipelineState);

const SimplePipeline2State = SimplePipelineState.override(.{
    .rasterizer_state = .{
        .cull_mode = .{ .back_bit = true },
    },
});
const SimplePipeline2 = program.pipeline.Object(SimplePipeline2State);

pub const SimpleCommand = struct {
    const Self = @This();

    base: program.command.IObject = .{
        .executeFn = execute,
    },

    vertex_buffer: *backend.buffer.Buffer,
    index_buffer: *backend.buffer.Buffer,

    pub fn build(render: *Render, vertex_buffer: *backend.buffer.Buffer, index_buffer: *backend.buffer.Buffer) !Self {
        try vertex_buffer.init(render.backend.context.allocator, &render.backend.vallocator, &render.backend.context);
        try index_buffer.init(render.backend.context.allocator, &render.backend.vallocator, &render.backend.context);

        return Self{
            .vertex_buffer = vertex_buffer,
            .index_buffer = index_buffer,
        };
    }

    pub fn deinit(self: Self) void {
        self.vertex_buffer.deinit();
        self.index_buffer.deinit();
    }

    pub fn execute(base: *const program.command.IObject, context: *const backend.Context, cb: backend.vk.CommandBuffer, fb: backend.Framebuffer) !void {
        const self = @fieldParentPtr(Self, "base", base);

        const offset = [_]backend.vk.DeviceSize{0};
        context.vkd.cmdBindVertexBuffers(cb, 0, 1, @ptrCast([*]const backend.vk.Buffer, &self.vertex_buffer.buffer()), &offset);
        context.vkd.cmdBindIndexBuffer(cb, self.index_buffer.buffer(), 0, .uint16);

        context.vkd.cmdDrawIndexed(cb, self.index_buffer.len(), 1, 0, 0, 0);
    }
};

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

    var clear_color = backend.vk.ClearValue{ .color = .{ .float_32 = [4]f32{ 1.0, 0.0, 0.0, 1.0 } } };

    const simple_render_pass = try SimpleRenderPass.build(&render, &clear_color);
    defer simple_render_pass.deinit();

    const simple_pipeline = try SimplePipeline.build(&render, &simple_render_pass);
    defer simple_pipeline.deinit();

    const simple_pipeline2 = try SimplePipeline2.build(&render, &simple_render_pass);
    defer simple_pipeline2.deinit();

    var vertex1 = Vertex.new(zm.Vec2f.new(-0.5, -0.5), zm.Vec3f.new(1.0, 0.0, 0.0));
    var vertex2 = Vertex.new(zm.Vec2f.new(0.5, -0.5), zm.Vec3f.new(0.0, 1.0, 0.0));
    var vertex3 = Vertex.new(zm.Vec2f.new(0.5, 0.5), zm.Vec3f.new(0.0, 0.0, 1.0));
    var vertex4 = Vertex.new(zm.Vec2f.new(-0.5, 0.5), zm.Vec3f.new(0.0, 0.0, 0.0));
    var vertex_buffer = backend.buffer.DirectBuffer(Vertex, .Vertex).new(&[_]Vertex{ vertex1, vertex2, vertex3, vertex4 });

    var indices = [_]u16{ 0, 1, 2, 2, 3, 0 };
    var index_buffer = backend.buffer.DirectBuffer(u16, .Index).new(&indices);

    const simple_command = try SimpleCommand.build(&render, &vertex_buffer.buf, &index_buffer.buf);
    defer simple_command.deinit();

    var vertex12 = Vertex.new(zm.Vec2f.new(-0.5, -0.5), zm.Vec3f.new(1.0, 0.0, 0.0));
    var vertex22 = Vertex.new(zm.Vec2f.new(0.5, -0.5), zm.Vec3f.new(0.0, 1.0, 0.0));
    var vertex32 = Vertex.new(zm.Vec2f.new(0.5, 0.5), zm.Vec3f.new(0.0, 0.0, 1.0));
    var vertex42 = Vertex.new(zm.Vec2f.new(-0.5, 0.5), zm.Vec3f.new(0.0, 0.0, 0.0));
    var vertex_buffer2 = backend.buffer.DirectBuffer(Vertex, .Vertex).new(&[_]Vertex{ vertex12, vertex22, vertex32, vertex42 });

    var indices2 = [_]u16{ 0, 1, 2, 2, 3, 0 };
    var index_buffer2 = backend.buffer.DirectBuffer(u16, .Index).new(&indices2);

    const simple_command2 = try SimpleCommand.build(&render, &vertex_buffer2.buf, &index_buffer2.buf);
    defer simple_command2.deinit();

    const simple_program = program.Program.build(&render.backend.context, &[_]program.Step{
        .{ .RenderPass = &simple_render_pass.base },

        .{ .Pipeline = &simple_pipeline.base },
        .{ .Command = &simple_command.base },

        .{ .Pipeline = &simple_pipeline2.base },
        .{ .Command = &simple_command2.base },
    });

    var counter: f32 = 0;
    while (testWindow.isRunning()) {
        counter += 0.001;

        testWindow.update();

        clear_color.color.float_32[0] = @sin(counter);
        clear_color.color.float_32[1] = @sin(-counter);
        clear_color.color.float_32[2] = @cos(counter);

        vertex1.color.x = @cos(-counter);
        vertex2.color.y = @cos(-counter);
        vertex3.color.z = @cos(-counter);
        vertex4.color.x = @cos(-counter);
        vertex1.pos.x = @cos(counter);
        vertex1.pos.y = @cos(counter);
        vertex2.pos.x = @cos(-counter);
        vertex2.pos.y = @sin(-counter);

        try vertex_buffer.update(&[_]Vertex{ vertex1, vertex2, vertex3, vertex4 });

        try render.backend.present(&simple_program);

        // try render.backend.vallocator.gc();
    }

    render.stop();
}
