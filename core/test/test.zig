const std = @import("std");
const warn = std.debug.warn;

const testing = std.testing;

usingnamespace @import("zetacore");

const HealthComponent = struct {
    health: usize,
};
const EnergyComponent = struct {
    energy: usize,
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

const ECS = @import("zetacore").Schema(u24, .{
    HealthComponent,
    EnergyComponent,
    PositionComponent,
    VelocityComponent,
});

const PhysicsSystem = struct {
    const Self = @This();
    system: ECS.System,

    pub fn init() Self {
        return Self{
            .system = ECS.System{
                .runFn = run,
            },
        };
    }

    fn run(sys: *ECS.System, world: *ECS.World) !void {
        var query = try world.queryAOS(struct {
            pos: *PositionComponent,
            vel: *VelocityComponent,
        });
        defer query.deinit();

        var timer = try std.time.Timer.start();
        for (query.items) |q| {
            q.pos.x += q.vel.x;
            q.pos.y += q.vel.y;
            q.pos.z += q.vel.z;
        }
        const end = timer.lap();
        warn("time: \t{d}\n", .{@intToFloat(f64, end) / 1000000000});
    }
};

test "generalECSTest" {
    std.debug.warn("\n", .{});

    var world = try ECS.World.init(std.heap.page_allocator);
    defer world.deinit();

    var i: usize = 0;
    while (i < 10000) : (i += 1) {
        _ = try world.createEntity(.{
            VelocityComponent{ .x = 1.0, .y = 1.0, .z = 1.0 },
            PositionComponent{ .x = 0.0, .y = 0.0, .z = 0.0 },
        });
    }

    var entity0 = try world.createEntity(.{
        HealthComponent{ .health = 20 },
    });

    var healths1 = try std.heap.page_allocator.alloc(HealthComponent, 10);
    std.mem.set(HealthComponent, healths1, HealthComponent{ .health = 20 });
    try world.createEntities(.{
        healths1,
    });

    var physicsSystem = PhysicsSystem.init();

    try world.registerSystem(&physicsSystem.system);

    try world.run();

    // Check to make sure that the iteration actually did something
    var query = try world.queryAOS(struct {
        pos: *PositionComponent,
        vel: *VelocityComponent,
    });
    defer query.deinit();

    for (query.items) |q| {
        testing.expectEqual(q.pos.x, q.vel.x);
    }
}

test "ecsBench" {
    warn("\n", .{});

    var world = try ECS.World.init(std.heap.page_allocator);
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
    warn("create: \t{d}\n", .{@intToFloat(f64, end) / 1000000000});

    std.heap.page_allocator.free(velocities0);
    std.heap.page_allocator.free(positions0);

    var query = try world.queryAOS(struct {
        pos: *PositionComponent,
        vel: *VelocityComponent,
    });
    defer query.deinit();

    timer.reset();
    for (query.items) |q| {
        q.pos.x += q.vel.x;
        q.pos.y += q.vel.y;
        q.pos.z += q.vel.z;
    }
    end = timer.lap();
    warn("query_aos (iter): \t{d}\n", .{@intToFloat(f64, end) / 1000000000});

    // Check to make sure that the iteration actually did something
    var query2 = try world.queryAOS(struct{
        pos: *PositionComponent,
        vel: *VelocityComponent,
    });
    defer query2.deinit();

    for (query2.items) |q| {
        testing.expectEqual(q.pos.x, q.vel.x);
    }
}

test "anyVecStoreTest" {
    std.debug.warn("\n", .{});

    var store = AnyVecStore.init(u32, std.heap.page_allocator);
    defer store.deinit();

    try store.append(u32, 11111);
    try store.append(u32, 22222);
    try store.append(u32, 33333);
    try store.append(u32, 44444);
    try store.append(u32, 55555);

    testing.expect(store.getIndex(u32, 0) == 11111);
    testing.expect(store.getIndex(u32, 1) == 22222);
    testing.expect(store.getIndex(u32, 2) == 33333);
    testing.expect(store.getIndex(u32, 3) == 44444);
    testing.expect(store.getIndex(u32, 4) == 55555);

    store.setIndex(u32, 1, 77777);
    testing.expect(store.getIndex(u32, 1) == 77777);

    testing.expect(store.getIndexPtr(u32, 1).* == 77777);

    var store2 = try AnyVecStore.initCapacity(u32, 5, std.heap.page_allocator);
    testing.expect(store2.len == 5);
    testing.expect(store2.data_len == @sizeOf(u32) * 5);

    try store2.append(u32, 11111);
    testing.expect(store2.getIndex(u32, 5) == 11111);

    store2.setIndex(u32, 0, 77777);
    testing.expect(store2.getIndex(u32, 0) == 77777);
}

test "multiVecStoreTest" {
    std.debug.warn("\n", .{});

    var store = MultiVecStore.init(std.heap.page_allocator);
    defer store.deinit();

    try store.append(u32, 11111);
    try store.append(u32, 22222);
    try store.append(u32, 33333);
    try store.append(PositionComponent, PositionComponent{ .x = 0.0, .y = 0.0, .z = 0.0 });
    try store.append(PositionComponent, PositionComponent{ .x = 1.0, .y = 1.0, .z = 1.0 });
    try store.append(u32, 44444);
    try store.append(u32, 55555);

    testing.expect(store.getIndex(u32, 0) == 11111);
    testing.expect(store.getIndex(u32, 1) == 22222);
    testing.expect(store.getIndex(u32, 2) == 33333);
    testing.expect(store.getIndex(PositionComponent, 3).x == 0.0);
    testing.expect(store.getIndex(PositionComponent, 4).x == 1.0);
    testing.expect(store.getIndex(u32, 5) == 44444);
    testing.expect(store.getIndex(u32, 6) == 55555);

    store.setIndex(u32, 1, 77777);
    testing.expect(store.getIndex(u32, 1) == 77777);

    testing.expect(store.getIndexPtr(u32, 1).* == 77777);

    var store2 = try MultiVecStore.initCapacity(.{ u32, f32 }, 2, std.heap.page_allocator);
    defer store2.deinit();

    testing.expect(store2.data_len == 16);
}
