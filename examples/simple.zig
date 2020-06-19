const std = @import("std");

const zc = @import("zetacore");
// const zm = @import("zetamath");
// const zr = @import("zetarender");

const ECS = zc.Schema(u20, .{
    HealthComponent,
    PositionComponent,
    VelocityComponent,
});

const HealthComponent = struct {
    health: usize,
};
const PositionComponent = struct {
    x: f32,
    y: f32,
    z: f32,
};
const VelocityComponent = struct {
    x: f32,
    y: f32,
    z: f32,
};

pub fn main() !void {
    var world = try ECS.World.init(std.heap.c_allocator);
    defer world.deinit();

    var velocities0 = try std.heap.page_allocator.alloc(VelocityComponent, 1000000);
    std.mem.set(VelocityComponent, velocities0, VelocityComponent{ .x = 1.0, .y = 1.0, .z = 1.0 });
    var positions0 = try std.heap.page_allocator.alloc(PositionComponent, 1000000);
    std.mem.set(PositionComponent, positions0, PositionComponent{ .x = 0.0, .y = 0.0, .z = 0.0 });

    var timer = try std.time.Timer.start();

    try world.createEntities(.{
        positions0,
        velocities0,
    });

    var end = timer.lap();
    std.debug.warn("create: \t{d}\n", .{@intToFloat(f64, end) / 1000000000});

    std.heap.page_allocator.free(velocities0);
    std.heap.page_allocator.free(positions0);
}
