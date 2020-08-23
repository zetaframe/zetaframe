pub const Pass = @import("pass.zig").Pass;
pub const renderpass = @import("renderpass.zig");
pub const pipeline = @import("pipeline.zig");
pub const descriptor = @import("descriptor.zig");

pub fn Program(Passes: anytype) type {
    return struct {
        const Self = @This();

        passes: [Passes.len]Pass,

        pub fn init() Self{
            var ps: [Passes.len]Pass = undefined;
            comptime for (Passes) |pass, i| {
                if (@TypeOf(pass) != Pass) @compileError("Not a pass interface!");
                ps[i] = pass;
            };

            return Self{
                .passes = ps,
            };
        }

        pub fn execute(self: *const Self) !void {
            for (self.passes) |pass| {
                try pass.execute();
            }
        }
    };
}