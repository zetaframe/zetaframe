const std = @import("std");

const zc = @import("zetacore");
const zm = @import("zetamath");
const zr = @import("zetarender");

const ECS = zc.Schema(u22, .{
    HealthComponent,
    PositionComponent,
    VelocityComponent,
});

const HealthComponent = struct {
    health: usize,
};
const PositionComponent = struct {
    pos: zm.Vec2f,
};
const VelocityComponent = struct {
    vel: zm.Vec2f,
};

pub fn main() !void {
    var world = try ECS.World.init(std.heap.c_allocator);
    defer world.deinit();

    var timer = try std.time.Timer.start();

    var i: usize = 0;
    while (i < 1000000) : (i += 1) {
        _ = try world.createEntity(.{
            VelocityComponent{ .vel = zm.Vec2f.One },
            PositionComponent{ .pos = zm.Vec2f.Zero },
        });
    }

    var end = timer.lap();
    std.debug.warn("create (loop): \t{d}\n", .{@intToFloat(f64, end) / 1000000000});

    var velocities0 = try std.heap.page_allocator.alloc(VelocityComponent, 1000000);
    std.mem.set(VelocityComponent, velocities0, VelocityComponent{ .vel = zm.Vec2f.One });
    var positions0 = try std.heap.page_allocator.alloc(PositionComponent, 1000000);
    std.mem.set(PositionComponent, positions0, PositionComponent{ .pos = zm.Vec2f.Zero });

    timer.reset();

    try world.createEntities(.{
        velocities0,
        positions0,
    });

    end = timer.lap();
    std.debug.warn("create (slice): \t{d}\n", .{@intToFloat(f64, end) / 1000000000});

    std.heap.page_allocator.free(velocities0);
    std.heap.page_allocator.free(positions0);
}
