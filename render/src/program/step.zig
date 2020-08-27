const RenderPassObject = @import("renderpass.zig").IObject;
const PipelineObject = @import("pipeline.zig").IObject;
const CommandObject = @import("command.zig").IObject;

pub const Step = union(enum) {
    RenderPass: *const RenderPassObject,
    Pipeline: *const PipelineObject,
    Command: *const CommandObject,
};
