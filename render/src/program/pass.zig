const PipelineState = @import("pipeline.zig").IState;

pub const Pass = struct {
    pipeline_state: *const PipelineState,

    pub fn execute(self: Pass) !void {
        try self.pipeline_state.execute();
    }
};