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
    pos: [3]f32,
};
const VelocityComponent = struct {
    vel: [3]f32,
};

const ECS = @import("zetacore").Schema(u20, .{
    HealthComponent,
    EnergyComponent,
    PositionComponent,
    VelocityComponent,
});

const DamageSystem = struct {
    const Self = @This();
    system: ECS.System,

    pub fn init() Self {
        return Self{
            .system = ECS.System{
                .runFn = run,
            },
        };
    }

    fn run(sys: *ECS.System) void {
        std.debug.warn("\nDamaged!\n", .{});
    }
};

fn HungerSystem() void {
    std.debug.warn("\nHungered!\n", .{});
}

pub fn rtest() !void {
    std.debug.warn("\n", .{});

    try generalECSTest();
    // try lotsOfEntities();
    // try ecsBench();
    // try anyVecStoreTest();
    // try multiVecStoreTest();
}

fn generalECSTest() !void {
    const EntityCreationData0 = struct {
        velocities: []VelocityComponent,
        position: []PositionComponent,
    };

    const EntityCreationData1 = struct {
        health: HealthComponent,
    };

    const EntityCreationData2 = struct {
        healths: []HealthComponent,
        positions: []PositionComponent,
    };

    var world = try ECS.World.init(std.heap.page_allocator);
    defer world.deinit();

    var velocities0 = [_]VelocityComponent{VelocityComponent{ .vel = [3]f32{ 0.0, 0.0, 0.0 } }} ** 10000;
    var positions0 = [_]PositionComponent{PositionComponent{ .pos = [3]f32{ 0.0, 0.0, 0.0 } }} ** 10000;

    const ecd0 = EntityCreationData0{
        .velocities = &velocities0,
        .position = &positions0,
    };

    try world.createEntities(EntityCreationData0, ecd0);

    var entity0 = try world.createEntity(EntityCreationData1, EntityCreationData1{
        .health = HealthComponent{ .health = 20 },
    });

    var healths0 = [_]HealthComponent{HealthComponent{ .health = 20 }} ** 1000;
    var positions1 = [_]PositionComponent{PositionComponent{ .pos = [3]f32{ 0.0, 0.0, 0.0 } }} ** 1000;

    const ecd1 = EntityCreationData2{
        .healths = &healths0,
        .positions = &positions1,
    };

    try world.createEntities(EntityCreationData2, ecd1);

    var damageSystem = DamageSystem.init();

    var query = try world.queryAOS(struct{
        pos: *PositionComponent,
        vel: *VelocityComponent,
    });

    const timer = std.time.Timer.start() catch @panic("timer needed");
    const start = timer.read();
    for (query) |q| {
        q.pos.pos[0] += q.vel.vel[0];
        q.pos.pos[1] += q.vel.vel[1];
        q.pos.pos[2] += q.vel.vel[2];
    }
    const end = timer.read();
    warn("time: {}\n", .{end - start});
    warn("----- ----- -----\n", .{});

    try world.registerSystem(&damageSystem.system);

    world.run();
}

fn lotsOfEntities() !void {
    warn("----- lots_of_entities -----\n", .{});
    const EntityCreationData = struct {
        health: HealthComponent,
        energy: EnergyComponent,
        position: PositionComponent,
    };
    const timer = std.time.Timer.start() catch @panic("timer needed");
    const start = timer.read();

    var world = try ECS.World.init(std.heap.page_allocator);
    defer world.deinit();

    var i: usize = 0;
    while (i < std.math.maxInt(u20) - 1) : (i += 1) {
        _ = try world.createEntity(EntityCreationData, EntityCreationData{
            .health = HealthComponent{ .health = i },
            .energy = EnergyComponent{ .energy = i * 2 },
            .position = PositionComponent{ .pos = [3]f32{ 0.0, 0.0, 0.0 } },
        });
    }

    i = 0;
    while (i < std.math.maxInt(u20) - 1) : (i += 1) {
        try world.deleteEntity(ECS.Entity{ .id = @intCast(u20, i), .internal = 0, .priority = 0 });
    }

    const end = timer.read();
    warn("entities: {}\n", .{std.math.maxInt(u20)});
    warn("time: {}\n", .{end - start});
    warn("----- ----- -----\n", .{});
}

fn ecsBench() !void {
    warn("----- ecs_bench -----\n", .{});
    const EntityCreationData = struct {
        velocities: []VelocityComponent,
        position: []PositionComponent,
    };

    const EntityCreationData2 = struct {
        position: []PositionComponent,
    };

    const timer = std.time.Timer.start() catch @panic("timer needed");
    const start = timer.read();

    var world = try ECS.World.init(std.heap.page_allocator);
    defer world.deinit();

    var velocities0 = [_]VelocityComponent{VelocityComponent{ .vel = [3]f32{ 0.0, 0.0, 0.0 } }} ** 10000;
    var positions0 = [_]PositionComponent{PositionComponent{ .pos = [3]f32{ 0.0, 0.0, 0.0 } }} ** 10000;

    const ecd0 = EntityCreationData{
        .velocities = &velocities0,
        .position = &positions0,
    };

    try world.createEntities(EntityCreationData, ecd0);

    var positions1 = [_]PositionComponent{PositionComponent{ .pos = [3]f32{ 0.0, 0.0, 0.0 } }} ** 90000;

    const ecd1 = EntityCreationData2{
        .position = &positions1,
    };

    try world.createEntities(EntityCreationData2, ecd1);

    const end = timer.read();
    warn("time: {}\n", .{end - start});
    warn("----- ----- -----\n", .{});
}

fn anyVecStoreTest() !void {
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

fn multiVecStoreTest() !void {
    var store = MultiVecStore.init(std.heap.page_allocator);
    defer store.deinit();

    try store.append(u32, 11111);
    try store.append(u32, 22222);
    try store.append(u32, 33333);
    try store.append(PositionComponent, PositionComponent{ .pos = [3]f32{ 0.0, 0.0, 0.0 } });
    try store.append(PositionComponent, PositionComponent{ .pos = [3]f32{ 1.0, 1.0, 1.0 } });
    try store.append(u32, 44444);
    try store.append(u32, 55555);

    testing.expect(store.getIndex(u32, 0) == 11111);
    testing.expect(store.getIndex(u32, 1) == 22222);
    testing.expect(store.getIndex(u32, 2) == 33333);
    testing.expect(store.getIndex(PositionComponent, 3).pos[0] == 0.0);
    testing.expect(store.getIndex(PositionComponent, 4).pos[1] == 1.0);
    testing.expect(store.getIndex(u32, 5) == 44444);
    testing.expect(store.getIndex(u32, 6) == 55555);

    store.setIndex(u32, 1, 77777);
    testing.expect(store.getIndex(u32, 1) == 77777);

    testing.expect(store.getIndexPtr(u32, 1).* == 77777);

    var store2 = try MultiVecStore.initCapacity(.{ u32, f32 }, 2, std.heap.page_allocator);
    defer store2.deinit();

    testing.expect(store2.data_len == 16);
}
