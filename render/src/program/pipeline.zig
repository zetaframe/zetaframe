const vk = @import("../include/vk.zig");

const DescriptorSetLayout = @import("descriptor.zig").SetLayout;
const RenderPass = @import("renderpass.zig").RenderPass;

pub const IState = struct {
    executeFn: fn (self: *const IState) anyerror!void,

    pub fn execute(self: *const IState) !void {
        try self.executeFn(self);
    }
};

pub const StateConfig = struct {
    render_pass: RenderPass,
    layout: Layout,

    topology: vk.PrimitiveTopology,
    primitive_restart: bool,

    shader_stages: []const ShaderStage,

    vertex_input_state: VertexInputState,
    rasterizer_state: RasterizerState,
    multisample_state: ?MultisampleState,
    depth_stencil_state: ?DepthStencilState,
    color_blend_state: ColorBlendState,
};

pub fn State(comptime config: StateConfig) type {
    return struct {
        const Self = @This();

        state: IState = IState{
            .executeFn = execute,
        },

        pub fn execute(state: *const IState) !void {
            const self = @fieldParentPtr(Self, "state", state);
        }
    };
}

pub const Layout = struct {
    set_layouts: []const DescriptorSetLayout,
};

pub const ShaderStage = struct {
    stage: vk.ShaderStageFlags,

    shader: union(enum) {
        path: []const u8,
        bytes: [:0]align(@alignOf(u32)) const u8,
    },
};

pub const VertexInputState = struct {
    input_rate: vk.VertexInputRate,
    bindings: []const ?type,
};

pub const RasterizerState = struct {};

pub const MultisampleState = struct {};

pub const DepthStencilState = struct {};

pub const ColorBlendState = struct {};
