const std = @import("std");
const vk = @import("../include/vk.zig");

const Render = @import("../lib.zig").Render;
const Context = @import("../backend/context.zig").Context;

pub const SetLayout = struct {
    bindings: []const Binding,
};

pub const Binding = struct {
    kind: vk.DescriptorType,
    count: u32,
    stages: vk.ShaderStageFlags,
};
