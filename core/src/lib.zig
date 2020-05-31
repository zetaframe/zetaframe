const std = @import("std");

const math = std.math;

const mem = std.mem;
const Allocator = mem.Allocator;

const assert = std.debug.assert;

const trait = std.meta.trait;

const builtin = @import("builtin");

// ECS
pub fn World(comptime entityT: type, comptime storageT: type, comptime componentT: type) type {
    if (comptime !trait.isUnsignedInt(entityT)) {
        @compileError("Entity type '" ++ @typeName(entityT) ++ "' must be an unsigned int.");
    }
    if (comptime @mod(@typeInfo(entityT).Int.bits, 2) != 0) {
        @compileError("Entity type must be divisible by two");
    }

    if (comptime !trait.isUnsignedInt(storageT)) {
        @compileError("Storage ID type '" ++ @typeName(entityT) ++ "' must be an unsigned int.");
    }
    if (comptime @mod(@typeInfo(storageT).Int.bits, 2) != 0) {
        @compileError("Storage ID type must be divisible by two");
    }

    if (comptime !trait.is(.Union)(componentT)) {
        @compileError("Component Type must be a union representing all used component types");
    }

    return struct {
        pub const Entity = struct {
            id: entityT,
            internal: entityT,
        };

        pub const WorldComponentStorage = ComponentStorage(entityT, storageT, componentT);

        const Self = @This();
        allocator: *Allocator,

        //----- Entities
        entities: []?Entity,
        current_entityid: entityT = 0,
        entities_deleted: entityT = 0,
        next_recycleid: ?entityT = null,

        //----- Components
        component_storages: []WorldComponentStorage,

        //----- Systems
        systems: std.AutoHashMap(*System, void),
        current_systemid: storageT = 0,

        //----- Resources

        pub fn init(allocator: *Allocator) !Self {
            var entities = try allocator.alloc(?Entity, math.maxInt(entityT));
            errdefer allocator.free(entities);

            var component_storages = try allocator.alloc(WorldComponentStorage, @typeInfo(componentT).Union.fields.len);
            errdefer allocator.free(component_storages);

            var systems = std.AutoHashMap(*System, void).init(allocator);

            var i: usize = 0;
            while (i < @typeInfo(componentT).Union.fields.len) {
                var storage = try WorldComponentStorage.init(allocator, @intCast(storageT, i));
                component_storages[i] = storage;
                i += 1;
            }

            return Self{
                .allocator = allocator,

                .entities = entities,
                .component_storages = component_storages,
                .systems = systems,
            };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.entities);
            self.allocator.free(self.component_storages);
            self.systems.deinit();
        }

        //----- Entities
        pub fn createEntity(self: *Self) EntityBuilder(entityT, storageT, componentT) {
            if (self.entities_deleted == 0) {
                const entity = Entity{
                    .id = self.current_entityid,
                    .internal = self.current_entityid,
                };
                self.entities[self.current_entityid] = entity;

                self.current_entityid += 1;

                return EntityBuilder(entityT, storageT, componentT).init(self.allocator, self, entity);
            } else {
                if (self.entities[self.next_recycleid.?] == null) {
                    const entity = Entity{
                        .id = self.next_recycleid.?,
                        .internal = self.next_recycleid.?,
                    };

                    self.next_recycleid = null;
                    self.entities[entity.id] = entity;

                    self.entities_deleted -= 1;

                    return EntityBuilder(entityT, storageT, componentT).init(self.allocator, self, entity);
                } else {
                    const entity = Entity{
                        .id = self.next_recycleid.?,
                        .internal = self.next_recycleid.?,
                    };

                    self.next_recycleid = self.entities[entity.id].?.id;
                    self.entities[entity.id] = entity;

                    self.entities_deleted -= 1;

                    return EntityBuilder(entityT, storageT, componentT).init(self.allocator, self, entity);
                }
            }
        }

        pub fn deleteEntity(self: *Self, entity: Entity) !void {
            if (self.next_recycleid == null) {
                self.entities[entity.id] = null;
                self.next_recycleid = entity.id;
            } else {
                self.entities[entity.id] = Entity{
                    .id = self.next_recycleid.?,
                    .internal = entity.id,
                };
                self.next_recycleid = entity.id;
            }

            self.entities_deleted += 1;

            for (self.component_storages) |*storage| {
                _ = storage.remove(entity) catch null;
            }
        }

        pub fn doesEntityExist(self: *Self, entity: Entity) bool {
            if (entity.id <= self.entities.len) return true else return false;
        }

        pub fn isEntityAlive(self: *Self, entity: Entity) bool {}

        //----- Components

        //----- Systems
        pub fn registerSystem(self: *Self, system: *System) !void {
            _ = try self.systems.put(system, {});
        }

        pub fn run(self: *Self) void {
            var iter = self.systems.iterator();
            while (iter.next()) |system| {
                system.key.run();
            }
        }

        //----- Resources.
    };
}

pub fn EntityBuilder(comptime entityT: type, comptime storageT: type, comptime componentT: type) type {
    return struct {
        const Self = @This();
        const Entity = World(entityT, storageT, componentT).Entity;
        allocator: *Allocator,
        world: *World(entityT, storageT, componentT),

        entity: Entity,
        components: std.AutoHashMap(componentT, void),

        pub fn init(allocator: *Allocator, world: *World(entityT, storageT, componentT), entity: Entity) Self {
            return Self{
                .allocator = allocator,
                .world = world,

                .entity = entity,
                .components = std.AutoHashMap(componentT, void).init(allocator),
            };
        }

        pub fn withComponent(self: Self, component: componentT) Self {
            _ = self.components.put(component, {}) catch null;
            return Self {
                .allocator = self.allocator,
                .world = self.world,

                .entity = self.entity,
                .components = self.components,
            };
        }

        pub fn build(self: *Self) !Entity {
            var iter = self.components.iterator();
            while (iter.next()) |component| {
                _ = try self.world.*.component_storages[@enumToInt(component.key)].add(self.entity, component.key);
            }
            self.components.deinit();
            return self.entity;
        }
    };
}

pub fn ComponentStorage(comptime entityT: type, comptime storageT: type, comptime componentT: type) type {
    return struct {
        const Self = @This();
        const Entity = World(entityT, storageT, componentT).Entity;
        allocator: *Allocator,
        component_id: storageT,

        dense: std.ArrayList(entityT),
        dense_len: entityT = 0,
        sparse: std.ArrayList(entityT),
        components: std.ArrayList(componentT),

        pub fn init(allocator: *Allocator, component_id: storageT) !Self {
            var dense = std.ArrayList(entityT).init(allocator);
            var sparse = std.ArrayList(entityT).init(allocator);
            var components = std.ArrayList(componentT).init(allocator);

            return Self{
                .allocator = allocator,
                .component_id = component_id,

                .dense = dense,
                .sparse = sparse,
                .components = components,
            };
        }

        pub fn deinit(self: *Self) void {
            self.components.deinit();
            self.dense.deinit();
            self.sparse.deinit();
        }

        pub fn len(self: Self) entityT {
            return self.dense_len;
        }

        pub fn toComponentSlice(self: Self) []componentT {
            return self.components.items;
        }

        pub fn add(self: *Self, entity: Entity, component: componentT) !entityT {
            if (@enumToInt(component) != self.component_id) {
                return error.ComponentDifferent;
            }
            if (self.entityExists(entity)) {
                return error.AlreadyRegistered;
            }

            try self.sparse.resize(entity.id + 1);

            try self.dense.append(entity.id);
            try self.components.append(component);

            self.sparse.items[entity.id] = self.dense_len;

            self.dense_len += 1;
            return self.dense_len - 1;
        }

        pub fn remove(self: *Self, entity: Entity) !void {
            if (!self.entityExists(entity)) {
                return error.NotRegistered;
            }

            self.dense_len -= 1;

            const last_sparse = self.dense.items[self.dense_len];
            const dense = self.sparse.items[entity.id];

            _ = self.dense.swapRemove(dense);
            _ = self.components.swapRemove(dense);
            self.sparse.items[last_sparse] = dense;
        }

        pub fn entityExists(self: Self, entity: Entity) bool {
            if (entity.id >= self.sparse.items.len) {
                return false;
            }
            const dense = self.sparse.items[entity.id];
            return dense < self.dense_len and self.dense.items[dense] == entity.id;
        }

        pub fn getComponentByEntity(self: Self, entity: Entity) !*componentT {
            if (!self.entityExists(entity)) {
                return error.NotRegistered;
            }

            const dense = self.sparse.items[entity.id];
            return &self.components.items[dense];
        }

        pub fn getComponentByDense(self: Self, dense: entityT) !*componentT {
            if (dense >= self.dense_len) {
                return error.OutOfBounds;
            }

            return &self.components.items[dense];
        }
    };
}

pub const System = struct {
    runFn: fn(self: *System) void,

    pub fn run(self: *System) void {
        self.runFn(self);
    }
};

fn ResourceStorage(comptime entityT: type, comptime storageT: type, comptime resourceT: type) type {
    return struct {
        const Self = @This();
        const Entity = World(entityT, storageT, resourceT).Entity;
        allocator: *Allocator,
        component_id: storageT,

        dense: std.ArrayList(entityT),
        dense_len: entityT = 0,
        sparse: std.ArrayList(entityT),
        resources: std.ArrayList(resourceT),

        pub fn init(allocator: *Allocator, component_id: storageT) !Self {
            var dense = std.ArrayList(entityT).init(allocator);
            var sparse = std.ArrayList(entityT).init(allocator);
            var resources = std.ArrayList(resourceT).init(allocator);

            return Self{
                .allocator = allocator,
                .component_id = component_id,

                .dense = dense,
                .sparse = sparse,
                .resources = resources,
            };
        }

        pub fn deinit(self: *Self) void {
            self.resources.deinit();
            self.dense.deinit();
            self.sparse.deinit();
        }

        pub fn len(self: Self) entityT {
            return self.dense_len;
        }

        pub fn toResourceSlice(self: Self) []resourceT {
            return self.resources.items;
        }

        pub fn add(self: *Self, entity: Entity, resources: resourceT) !entityT {
            if (self.entityExists(entity)) {
                return error.AlreadyRegistered;
            }

            try self.sparse.resize(entity.id + 1);

            try self.dense.append(entity.id);
            try self.resources.append(resources);

            self.sparse.items[entity.id] = self.dense_len;

            self.dense_len += 1;
            return self.dense_len - 1;
        }

        pub fn remove(self: *Self, entity: Entity) !void {
            if (!self.entityExists(entity)) {
                return error.NotRegistered;
            }

            self.dense_len -= 1;

            const last_sparse = self.dense.items[self.dense_len];
            const dense = self.sparse.items[entity.id];

            _ = self.dense.swapRemove(dense);
            _ = self.resources.swapRemove(dense);
            self.sparse.items[last_sparse] = dense;
        }

        pub fn entityExists(self: Self, entity: Entity) bool {
            if (entity.id >= self.sparse.items.len) {
                return false;
            }
            const dense = self.sparse.items[entity.id];
            return dense < self.dense_len and self.dense.items[dense] == entity.id;
        }

        pub fn getResourceByEntity(self: Self, entity: Entity) !*resourceT {
            if (!self.entityExists(entity)) {
                return error.NotRegistered;
            }

            const dense = self.sparse.items[entity.id];
            return &self.resources.items[dense];
        }

        pub fn getResourceByDense(self: Self, dense: entityT) !*resourceT {
            if (dense >= self.dense_len) {
                return error.OutOfBounds;
            }

            return &self.resources.items[dense];
        }
    };
}