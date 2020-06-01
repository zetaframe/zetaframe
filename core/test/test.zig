const std = @import("std");
const warn = std.debug.warn;

const testing = std.testing;

usingnamespace @import("zetacore");

const HealthComponent = struct {
    health: u8,
};
const EnergyComponent = struct {
    energy: u8,
};
const PositionComponent = struct {
    pos: [3]f32,
};

const ECS = @import("zetacore").Schema(u8, .{
    HealthComponent,
    EnergyComponent,
    PositionComponent,
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

    var world = try ECS.World.init(std.heap.page_allocator);
    defer world.deinit();

    var damageSystem = DamageSystem.init();

    try world.registerSystem(&damageSystem.system);
    //try world.registerSystem(HungerSystem);

    var entity0_1 = try world.createEntity(.{});

    try world.deleteEntity(entity0_1);

    var entity0_2 = try world.createEntity(.{
        PositionComponent{ .pos = [3]f32{ 0.0, 0.0, 0.0 } },
    });

    testing.expect(entity0_2.id == 0);

    try world.deleteEntity(entity0_2);

    var entity0 = try world.createEntity(.{
        PositionComponent{ .pos = [3]f32{ 0.0, 0.0, 0.0 } },
    });

    testing.expect(entity0.id == 0);

    var entity1 = try world.createEntity(.{
        HealthComponent{ .health = 100 },
    });

    var entity2 = try world.createEntity(.{
        EnergyComponent{ .energy = 100 },
    });

    testing.expect((try world.component_storages.getIndexPtr(ECS.ComponentStorage(HealthComponent), 0)).len() == 1);

    try world.deleteEntity(entity0);

    testing.expect((try world.component_storages.getIndexPtr(ECS.ComponentStorage(HealthComponent), 0)).len() == 1);
    testing.expect((try world.component_storages.getIndexPtr(ECS.ComponentStorage(PositionComponent), 2)).len() == 0);

    var hComponent1 = try (try world.component_storages.getIndexPtr(ECS.ComponentStorage(HealthComponent), 0)).getComponentByEntity(entity1);
    testing.expect(hComponent1.*.health == 100);

    world.run();

    try anyVecStoreTest();
    try multiVecStoreTest();
}

fn anyVecStoreTest() !void {
    var store = AnyVecStore.init(u32, std.heap.page_allocator);
    defer store.deinit();

    try store.append(u32, 11111);
    try store.append(u32, 22222);
    try store.append(u32, 33333);
    try store.append(u32, 44444);
    try store.append(u32, 55555);

    testing.expect((try store.getIndex(u32, 0)) == 11111);
    testing.expect((try store.getIndex(u32, 1)) == 22222);
    testing.expect((try store.getIndex(u32, 2)) == 33333);
    testing.expect((try store.getIndex(u32, 3)) == 44444);
    testing.expect((try store.getIndex(u32, 4)) == 55555);

    try store.setIndex(u32, 1, 77777);
    testing.expect((try store.getIndex(u32, 1)) == 77777);

    testing.expect((try store.getIndexPtr(u32, 1)).* == 77777);

    var store2 = try AnyVecStore.initCapacity(u32, 5, std.heap.page_allocator);
    testing.expect(store2.len == 5);
    testing.expect(store2.data_len == @sizeOf(u32) * 5);

    try store2.append(u32, 11111);
    testing.expect((try store2.getIndex(u32, 5)) == 11111);

    try store2.setIndex(u32, 0, 77777);
    testing.expect((try store2.getIndex(u32, 0)) == 77777);
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

    testing.expect((try store.getIndex(u32, 0)) == 11111);
    testing.expect((try store.getIndex(u32, 1)) == 22222);
    testing.expect((try store.getIndex(u32, 2)) == 33333);
    testing.expect((try store.getIndex(PositionComponent, 3)).pos[0] == 0.0);
    testing.expect((try store.getIndex(PositionComponent, 4)).pos[1] == 1.0);
    testing.expect((try store.getIndex(u32, 5)) == 44444);
    testing.expect((try store.getIndex(u32, 6)) == 55555);

    try store.setIndex(u32, 1, 77777);
    testing.expect((try store.getIndex(u32, 1)) == 77777);

    testing.expect((try store.getIndexPtr(u32, 1)).* == 77777);

    var store2 = try MultiVecStore.initCapacity(.{ u32, f32 }, 2, std.heap.page_allocator);
    defer store2.deinit();

    testing.expect(store2.data_len == 16);
}
