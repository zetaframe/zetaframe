const std = @import("std");
const Allocator = std.mem.Allocator;

const Shader = @import("shader.zig").Shader;

const vk = @import("../include/vk.zig");
const zva = @import("zva");

const Context = @import("context.zig").Context;
const Buffer = @import("buffer.zig").Buffer;

pub const Uniform = struct {
    const Self = @This();
    allocator: *Allocator,
    vallocator: *zva.Allocator,

    context: *const Context,

    layout_binding: vk.DescriptorSetLayoutBinding,
    layout: vk.DescriptorSetLayout,

    pub fn new(comptime T: type, binding: u32, stage: vk.ShaderStageFlags) Self {
        return Self{
            .allocator = undefined,
            .vallocator = undefined,

            .context = undefined,

            .layout_binding = .{
                .binding = binding,
                .descriptor_type = .uniform_buffer,
                .descriptor_count = 1,

                .stage_flags = stage,
                .p_immutable_samplers = null,
            },
            .layout = undefined,
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, vallocator: *zva.Allocator, context: *const Context) !void {
        self.allocator = allocator;
        self.vallocator = vallocator;

        self.context = context;

        const layoutInfo = vk.DescriptorSetLayoutCreateInfo{
            .binding_count = 1,
            .p_bindings = @ptrCast([*]const vk.DescriptorSetLayoutBinding, &self.layout_binding),

            .flags = .{},
        };

        self.layout = try self.context.vkd.createDescriptorSetLayout(context.device, layoutInfo, null);
    }

    pub fn deinit(self: Self) void {
        self.context.vkd.destroyDescriptorSetLayout(self.context.device, self.layout, null);
    }
};