const std = @import("std");

const math = std.math;

const mem = std.mem;
const Allocator = mem.Allocator;

const assert = std.debug.assert;

const trait = std.meta.trait;

const builtin = @import("builtin");

/// ECS Schema with the IdType and all component types
pub fn Schema(comptime IdType: type, comptime CompTypes: var) type {
    if (comptime !trait.isUnsignedInt(IdType)) {
        @compileError("Id type '" ++ @typeName(IdType) ++ "' must be an unsigned int.");
    }
    if (comptime @mod(@typeInfo(IdType).Int.bits, 2) != 0) {
        @compileError("Id type must be divisible by two");
    }

    return struct {
        pub const Entity = struct {
            id: IdType,
            internal: IdType,
            priority: IdType = 0,
        };

        pub const World = struct {
            const Self = @This();
            allocator: *Allocator,

            //----- Entities
            entities: []?Entity,
            current_entityid: IdType = 0,
            entities_deleted: IdType = 0,
            next_recycleid: ?IdType = null,

            //----- Components
            component_storages: MultiVecStore,
            component_map: std.StringHashMap(IdType),

            //----- Systems
            systems: std.AutoHashMap(*System, void),
            current_systemid: IdType = 0,

            //----- Resources

            /// Initialize a world in this ECS
            /// Generates the required storages
            pub fn init(allocator: *Allocator) !Self {
                var entities = try allocator.alloc(?Entity, math.maxInt(IdType));
                errdefer allocator.free(entities);

                var component_storages = MultiVecStore.init(allocator);

                var component_map = std.StringHashMap(IdType).init(allocator);

                inline for (CompTypes) |T, i| {
                    var storage = try ComponentStorage(T).init(allocator, @intCast(IdType, i));
                    try component_storages.append(ComponentStorage(T), storage);
                    try component_map.putNoClobber(@typeName(T), i);
                }

                var systems = std.AutoHashMap(*System, void).init(allocator);

                return Self{
                    .allocator = allocator,

                    .entities = entities,

                    .component_storages = component_storages,
                    .component_map = component_map,

                    .systems = systems,
                };
            }

            /// Cleans up the world
            /// Deinits all the storages
            pub fn deinit(self: Self) void {
                self.allocator.free(self.entities);

                inline for (CompTypes) |T, i| {
                    self.component_storages.getIndex(ComponentStorage(T), i).deinit();
                }

                self.component_storages.deinit();
                self.component_map.deinit();

                self.systems.deinit();
            }

            //----- Entities

            /// Create a single entity with components
            /// Components are declared with a struct
            /// Ex:
            /// struct {
            ///     health: HealthComponent,
            ///     position: PositionComponent,
            ///}
            pub fn createEntity(self: *Self, comptime T: type, components: T) !Entity {
                var entity: Entity = undefined;
                if (self.entities_deleted == 0) {
                    entity = Entity{
                        .id = self.current_entityid,
                        .internal = self.current_entityid,
                    };
                    self.entities[self.current_entityid] = entity;

                    self.current_entityid += 1;
                } else {
                    if (self.entities[self.next_recycleid.?] == null) {
                        entity = Entity{
                            .id = self.next_recycleid.?,
                            .internal = self.next_recycleid.?,
                        };

                        self.next_recycleid = null;
                        self.entities[entity.id] = entity;

                        self.entities_deleted -= 1;
                    } else {
                        entity = Entity{
                            .id = self.next_recycleid.?,
                            .internal = self.next_recycleid.?,
                        };

                        self.next_recycleid = self.entities[entity.id].?.id;
                        self.entities[entity.id] = entity;

                        self.entities_deleted -= 1;
                    }
                }

                entity.priority = @typeInfo(T).Struct.fields.len;

                inline for (@typeInfo(T).Struct.fields) |field| {
                    const FieldT = field.field_type;
                    var index = self.component_map.getValue(@typeName(FieldT)) orelse return error.ComponentDoesNotExist;

                    _ = try self.component_storages.getIndexPtr(ComponentStorage(FieldT), index).add(entity, @field(components, field.name));
                }

                return entity;
            }

            /// Create multiple entities with components
            /// Components are declared with a struct
            /// Ex:
            /// struct {
            ///     healths: []HealthComponent,
            ///     positions: []PositionComponent,
            ///}
            pub fn createEntities(self: *Self, comptime T: type, components: T) !void {
                const entity = Entity{
                    .id = self.current_entityid,
                    .internal = self.current_entityid,
                    .priority = @typeInfo(T).Struct.fields.len,
                };

                var i: usize = 0;
                while (i < @field(components, @typeInfo(T).Struct.fields[0].name).len) : (i += 1) {
                    self.entities[self.current_entityid + i] = entity;
                }

                self.current_entityid += @intCast(IdType, @field(components, @typeInfo(T).Struct.fields[0].name).len);

                inline for (@typeInfo(T).Struct.fields) |field| {
                    const FieldT = @typeInfo(field.field_type).Pointer.child;
                    var index = self.component_map.getValue(@typeName(FieldT)) orelse return error.ComponentDoesNotExist;

                    _ = try self.component_storages.getIndexPtr(ComponentStorage(FieldT), index).addSlice(entity, @field(components, field.name));
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

                inline for (CompTypes) |T, i| {
                    _ = self.component_storages.getIndexPtr(ComponentStorage(T), i).remove(entity) catch null;
                }
            }

            /// Checks if the entity exists in the world
            /// Not to be confused with if the entity is alive
            pub fn doesEntityExist(self: *Self, entity: *Entity) bool {
                if (entity.id <= self.entities.len) return true else return false;
            }

            /// Checks if the entity is alive
            /// An alive entity is an entity that still contains components
            pub fn isEntityAlive(self: *Self, entity: *Entity) bool {
                if (self.doesEntityExist(entity) and entity.id == entity.internal) return true else return false;
            }

            /// Adds a single component to an entity
            pub fn addComponentToEntity(self: *Self, entity: *Entity, comptime T: type, component: T) !void {
                var index = self.component_map.getValue(@typeName(T)) orelse return error.ComponentDoesNotExist;
                _ = try self.component_storages.getIndexPtr(ComponentStorage(T), index).add(entity, component);
            }

            /// Adds multiple components to an entity
            /// Components are declared with a struct
            /// Ex:
            /// struct {
            ///     health: HealthComponent,
            ///     position: PositionComponent,
            ///}
            pub fn addComponentsToEntity(self: *Self, entity: *Entity, comptime T: type, components: T) !void {
                inline for (@typeInfo(T).Struct.fields) |field| {
                    const FieldT = field.field_type;
                    var index = self.component_map.getValue(@typeName(FieldT)) orelse return error.ComponentDoesNotExist;

                    _ = try self.component_storages.getIndexPtr(ComponentStorage(FieldT), index).add(entity, @field(components, field.name));
                }
            }

            /// Removes one component from an entity
            pub fn removeComponentFromEntity(self: *Self, entity: *Entity, comptime T: type) !void {
                var index = self.component_map.getValue(@typeName(T)) orelse return error.ComponentDoesNotExist;
                _ = try self.component_storages.getIndexPtr(ComponentStorage(T), index).remove(entity);
            }

            //----- Components
            /// Queries the world for entities that match the query
            /// Returns the entities in a AOS fashion
            pub fn queryAOS(self: *Self, comptime Query: type) ![]Query {
                var queries = std.ArrayList(Query).init(self.allocator);
                outer: for (self.entities) |_, i| {
                    if (self.entities[i] != null) {
                        var entity = self.entities[i].?;
                        if (!self.isEntityAlive(&entity)) continue;

                        var query: Query = undefined;
                        inline for (@typeInfo(Query).Struct.fields) |field| {
                            const FieldT = @typeInfo(field.field_type).Pointer.child;
                            var index = self.component_map.getValue(@typeName(FieldT)) orelse return error.ComponentDoesNotExist;

                            if (!self.component_storages.getIndexPtr(ComponentStorage(FieldT), index).has(entity)) continue :outer;
                            @field(query, field.name) = try self.component_storages.getIndexPtr(ComponentStorage(FieldT), index).getByEntity(entity);
                        }
                        try queries.append(query);
                    }
                }
                return queries.toOwnedSlice();
            }

            /// Queries the world for entities that match the query
            /// Returns the entities in a SOA fashion
            pub fn querySOA(self: *Self, comptime Query: type) Query {
                inline for (@typeInfo(Query).Struct.fields) |field| {
                    const FieldT = @typeInfo(field.field_type);
                    var index = self.component_map.getValue(@typeName(FieldT)) orelse return error.ComponentDoesNotExist;

                    _ = try self.component_storages.getIndexPtr(ComponentStorage(FieldT), index).add(entity, @field(components, field.name));
                }
            }

            //----- Systems

            /// Registers a system
            pub fn registerSystem(self: *Self, system: *System) !void {
                _ = try self.systems.put(system, {});
            }

            /// Start up the scheduler
            pub fn run(self: *Self) void {
                var iter = self.systems.iterator();
                while (iter.next()) |system| {
                    system.key.run();
                }
            }

            //----- Resources.
        };

        fn ComponentStorage(comptime CompType: type) type {
            return struct {
                const Self = @This();
                allocator: *Allocator,
                component_id: IdType,

                dense: std.ArrayList(IdType),
                dense_len: IdType = 0,
                sparse: std.ArrayList(IdType),
                components: std.ArrayList(CompType),

                pub fn init(allocator: *Allocator, component_id: IdType) !Self {
                    var dense = std.ArrayList(IdType).init(allocator);
                    var sparse = std.ArrayList(IdType).init(allocator);
                    var components = std.ArrayList(CompType).init(allocator);

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

                pub fn len(self: *Self) IdType {
                    return self.dense_len;
                }

                pub fn add(self: *Self, entity: Entity, component: CompType) !IdType {
                    if (self.has(entity)) {
                        return error.AlreadyRegistered;
                    }

                    try self.dense.append(entity.id);
                    try self.components.append(component);

                    try self.sparse.resize(entity.id + 1);
                    self.sparse.items[entity.id] = self.dense_len;

                    self.dense_len += 1;
                    return self.dense_len - 1;
                }

                pub fn addSlice(self: *Self, entity: Entity, components: []CompType) !void {
                    if (self.has(entity)) {
                        return error.AlreadyRegistered;
                    }

                    try self.sparse.resize(entity.id + components.len + 1);
                    try self.dense.resize(self.dense_len + components.len);

                    try self.components.appendSlice(components);

                    var i: IdType = 0;
                    while (i < components.len) : (i += 1) {
                        self.dense.items[self.dense_len + i] = entity.id + i;
                        self.sparse.items[entity.id + i] = self.dense_len + i;
                    }

                    self.dense_len += @intCast(IdType, components.len);
                }

                pub fn remove(self: *Self, entity: Entity) !CompType {
                    if (!self.has(entity)) {
                        return error.NotRegistered;
                    }

                    self.dense_len -= 1;

                    const last_sparse = self.dense.items[self.dense_len];
                    const dense = self.sparse.items[entity.id];

                    _ = self.dense.swapRemove(dense);
                    self.sparse.items[last_sparse] = dense;
                    return self.components.swapRemove(dense);
                }

                pub fn has(self: *Self, entity: Entity) bool {
                    if (entity.id >= self.sparse.items.len) {
                        return false;
                    }
                    const dense = self.sparse.items[entity.id];
                    return dense < self.dense_len and self.dense.items[dense] == entity.id;
                }

                pub fn getByEntity(self: *Self, entity: Entity) !*CompType {
                    if (!self.has(entity)) {
                        return error.NotRegistered;
                    }

                    const dense = self.sparse.items[entity.id];
                    return &self.components.items[dense];
                }

                pub fn getByDense(self: *Self, dense: IdType) !*CompType {
                    if (dense >= self.dense_len) {
                        return error.OutOfBounds;
                    }

                    return &self.components.items[dense];
                }

                fn swapIndicesDense(self: *Self, dense1: IdType, dense2: IdType) !void {
                    var tempSparse = elf.sparse.items[self.dense.items[dense1]];
                    self.sparse.items[self.dense.items[dense1]] = self.sparse.items[self.dense.items[dense2]];
                    self.sparse.items[self.dense.items[dense2]] = tempSparse;

                    var tempComponent = self.components.items[dense1];
                    self.components.items[dense1] = self.components.items[dense2];
                    self.components.items[dense2] = tempComponent;

                    var tempDense = self.dense.items[dense1];
                    self.dense.items[dense1] = self.dense.items[dense2];
                    self.dense.items[dense2] = tempDense;
                }
            };
        }

        pub const System = struct {
            runFn: fn (self: *System) void,

            pub fn run(self: *System) void {
                self.runFn(self);
            }
        };
    };
}

/// A Vector Storage that stores one type in a generic non comptime manner
/// Stores all entries as their raw bytes
pub const AnyVecStore = struct {
    const Self = @This();
    allocator: *Allocator,

    data: []u8,
    data_len: usize,
    len: usize,

    type_name: []const u8,
    type_size: usize,

    /// Initialize the AnyVecStore
    pub fn init(comptime T: type, allocator: *Allocator) Self {
        return Self{
            .allocator = allocator,

            .data = &[_]u8{},
            .data_len = 0,
            .len = 0,

            .type_name = @typeName(T),
            .type_size = @bitSizeOf(T),
        };
    }

    /// Initialize the AnyVecStore with a capacity
    pub fn initCapacity(comptime T: type, capacity: usize, allocator: *Allocator) !Self {
        return Self{
            .allocator = allocator,

            .data = try allocator.alloc(u8, @sizeOf(T) * capacity),
            .data_len = @sizeOf(T) * capacity,
            .len = capacity,

            .type_name = @typeName(T),
            .type_size = @bitSizeOf(T),
        };
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.data);
    }

    fn checkType(self: *const Self, comptime T: type) bool {
        const nameT = @typeName(T);
        const sizeT = @bitSizeOf(T);

        return mem.eql(u8, self.type_name, nameT) and self.type_size == sizeT;
    }

    pub fn append(self: *Self, comptime T: type, data: T) !void {
        assert(self.checkType(T));

        const sizeT = @sizeOf(T);

        self.data = try self.allocator.realloc(self.data, self.data_len + sizeT);

        const dataBytes = mem.toBytes(data);
        for (dataBytes[0..dataBytes.len]) |b, i| self.data[self.data_len + i] = b;

        self.data_len += sizeT;
        self.len += 1;
    }

    pub fn getIndex(self: *const Self, comptime T: type, index: usize) T {
        assert(self.checkType(T));
        assert(index < self.len);

        const sizeT = @sizeOf(T);
        const offset = sizeT * index;

        var dataBytes = self.data[offset .. offset + sizeT];
        return mem.bytesToValue(T, @ptrCast(*[sizeT]u8, dataBytes));
    }

    pub fn getIndexPtr(self: *Self, comptime T: type, index: usize) *T {
        assert(self.checkType(T));
        assert(index < self.len);

        const sizeT = @sizeOf(T);
        const offset = sizeT * index;

        var dataBytes = self.data[offset .. offset + sizeT];
        return @ptrCast(*T, @alignCast(@alignOf(T), dataBytes));
    }

    pub fn setIndex(self: *Self, comptime T: type, index: usize, data: T) void {
        assert(self.checkType(T));
        assert(index < self.len);

        const sizeT = @sizeOf(T);
        const offset = sizeT * index;

        const dataBytes = mem.toBytes(data);
        for (dataBytes[0..dataBytes.len]) |b, i| self.data[offset + i] = b;
    }
};

/// A Vector Storage that stores any type in a generic non comptime manner
/// Stores all entries as their raw bytes
/// Uses a hash map as an offset table
pub const MultiVecStore = struct {
    const Self = @This();
    allocator: *Allocator,

    data: []u8,
    data_len: usize,

    offset_map: std.AutoHashMap(usize, usize),

    len: usize,

    /// Initialize the MultiVecStore
    pub fn init(allocator: *Allocator) Self {
        return Self{
            .allocator = allocator,

            .data = &[_]u8{},
            .data_len = 0,

            .offset_map = std.AutoHashMap(usize, usize).init(allocator),

            .len = 0,
        };
    }

    /// Initialize the MultiVecStore with a capacity
    /// The capacity is all types * the capacity
    pub fn initCapacity(comptime Types: var, capacity: usize, allocator: *Allocator) !Self {
        var len: usize = 0;
        inline for (Types) |T| {
            len += @sizeOf(T) * capacity;
        }
        return Self{
            .allocator = allocator,

            .data = try allocator.alloc(u8, len),
            .data_len = len,

            .offset_map = std.AutoHashMap(usize, usize).init(allocator),

            .len = capacity * Types.len,
        };
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.data);
        self.offset_map.deinit();
    }

    pub fn append(self: *Self, comptime T: type, data: T) !void {
        const sizeT = @sizeOf(T);
        const offset = self.data_len;

        self.data = try self.allocator.realloc(self.data, offset + sizeT);

        const dataBytes = mem.toBytes(data);
        for (dataBytes[0..dataBytes.len]) |b, i| self.data[self.data_len + i] = b;

        try self.offset_map.putNoClobber(self.len, offset);

        self.data_len += sizeT;
        self.len += 1;
    }

    pub fn getIndex(self: *const Self, comptime T: type, index: usize) T {
        assert(index < self.len);

        const sizeT = @sizeOf(T);
        const offset = self.offset_map.getValue(index).?;

        var dataBytes = self.data[offset .. offset + sizeT];
        return mem.bytesToValue(T, @ptrCast(*[sizeT]u8, dataBytes));
    }

    pub fn getIndexPtr(self: *Self, comptime T: type, index: usize) *T {
        assert(index < self.len);

        const sizeT = @sizeOf(T);
        const offset = self.offset_map.getValue(index).?;

        var dataBytes = self.data[offset .. offset + sizeT];
        return @ptrCast(*T, @alignCast(@alignOf(T), dataBytes));
    }

    pub fn setIndex(self: *Self, comptime T: type, index: usize, data: T) void {
        assert(index < self.len);

        const sizeT = @sizeOf(T);
        const offset = self.offset_map.getValue(index).?;

        if (self.offset_map.getValue(index + 1) != null) {
            assert(self.offset_map.getValue(index + 1).? - offset == sizeT);
        }

        const dataBytes = mem.toBytes(data);
        for (dataBytes[0..dataBytes.len]) |b, i| self.data[offset + i] = b;
    }
};
