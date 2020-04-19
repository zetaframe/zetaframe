usingnamespace @import("zetacore");

const std = @import("std");

const testing = std.testing;

pub const Vec3 = struct {
    x: u32,
    y: u32,
    z: u32,
};

pub const Component = union(enum) {
    HealthComponent: u8,
    EnergyComponent: u8,
    PositionComponent: Vec3,
    VelocityComponent: Vec3,
    AccelerationComponent: Vec3,
};

fn DamageSystem() void {
    std.debug.warn("\nDamaged!\n", .{});
}

fn HungerSystem() void {
    std.debug.warn("\nHungered!\n", .{});
}

pub fn rtest() !void {
    var world = try World(u8, u8, Component).init(std.heap.page_allocator);
    defer world.deinit();

    try world.registerSystem(DamageSystem);
    try world.registerSystem(HungerSystem);

    var entity0_1 = try world.createEntity().build();

    try world.deleteEntity(entity0_1);

    var entity0_2 = try world.createEntity().withComponent(Component{ .HealthComponent = 20 }).build();

    testing.expect(entity0_2.id == 0);

    try world.deleteEntity(entity0_2);

    var entity0 = try world.createEntity().withComponent(Component{ .HealthComponent = 20 }).withComponent(Component{ .EnergyComponent = 20 }).build();

    testing.expect(entity0.id == 0);

    var entity1 = try world.createEntity().withComponent(Component{ .HealthComponent = 100 }).withComponent(Component{ .EnergyComponent = 210 }).build();
    var entity2 = try world.createEntity().withComponent(Component{ .HealthComponent = 200 }).withComponent(Component{ .PositionComponent = Vec3{ .x = 0, .y = 0, .z = 0 } }).build();

    testing.expect(world.component_storages[0].len() == 3);

    try world.deleteEntity(entity0);

    testing.expect(world.component_storages[0].len() == 2);
    var hComponent1 = try world.component_storages[0].getComponentByEntity(entity1);
    testing.expect(hComponent1.*.HealthComponent == 100);

    world.run();
}
