const vk = @import("../include/vk.zig");

pub const SetLayout = struct {
    bindings: []const Binding,
};

pub const Binding = struct {
    name: []const u8,
    kind: vk.DescriptorType,
    count: u32,
    stage_flags: vk.ShaderStageFlags,
};