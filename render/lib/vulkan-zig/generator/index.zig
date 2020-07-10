pub const generateVk = @import("vulkan/generator.zig").generate;
pub const VkGenerateStep = @import("vulkan/build-integration.zig").GenerateStep;

test "main" {
    _ = @import("xml.zig");
    _ = @import("c-parse.zig");
}
