const std = @import("std");
const warn = std.debug.warn;

const math = std.math;

const mem = std.mem;
const Allocator = mem.Allocator;

const assert = std.debug.assert;

const trait = std.meta.trait;

const testing = std.testing;

const builtin = @import("builtin");

pub fn World(comptime ComponentTypes: []const type) type {
    return struct {
        const Self = @This();

        pub fn init() Self {
            return Self{};
        }

        pub fn deinit() void {}
    };
}

pub fn Archetype() type {
    return struct {
        const Self = @This();
        allocator: *Allocator,

        chunks_dense: std.ArrayList(u32),
        chunks_sparse: std.ArrayList(u32),
        chunks: std.ArrayList(ArchetypeChunk()),
        chunks_len: u32 = 0,

        pub fn init(allocator: *Allocator) !Self {
            var chunksDense = try std.ArrayList(u32).init(allocator);
            var chunksSparse = try std.ArrayList(u32).init(allocator);
            var chunks = try std.ArrayList(ArchetypeChunk()).init(allocator);

            return Self{
                .allocator = allocator,

                .chunks_dense = chunksDense,
                .chunks_sparse = chunksSparse,
                .chunks = chunks,
            };
        }

        pub fn deinit(self: *Self) void {
            self.chunks_dense.deinit();
            self.chunks_sparse.deinit();
            self.chunks.deinit();
        }

        pub fn add(self: *Self) !void {

        }
    };
}

pub fn ArchetypeChunk() type {
    return struct {

    };
}

test "ecs" {
    warn("\n", .{});
    const PositionComponent = struct {
        pos: [3]f32,
    };

    const VelocityComponent = struct {
        pos: [3]f32,
    };

    const AccelerationComponent = struct {
        pos: [3]f32,
    };

    const world = World(&[_]type{
        PositionComponent,
        VelocityComponent,
        AccelerationComponent,
    }).init();
}

pub const AnyVecStore = struct {
    const Self = @This();
    allocator: *Allocator,

    data: []u8,
    data_len: usize,
    len: usize,

    type_name: []const u8,

    pub fn init(comptime T: type, allocator: *Allocator) !Self {
        return Self{
            .allocator = allocator,

            .data = &[_]u8{},
            .data_len = 0,
            .len = 0,

            .type_name = @typeName(T),
        };
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.data);
    }

    fn checkType(self: *Self, comptime T: type) bool {
        const nameT = @typeName(T);

        return mem.eql(u8, self.type_name, nameT);
    }

    pub fn append(self: *Self, comptime T: type, data: T) !void {
        if (!self.checkType(T)) return error.TypeIncorrect;

        const sizeT = @sizeOf(T);

        self.data = try self.allocator.realloc(self.data, self.data_len + sizeT);

        const dataBytes = mem.toBytes(data);
        for (dataBytes[0..dataBytes.len]) |b, i| self.data[self.data_len + i] = b;

        self.data_len += sizeT;
        self.len += 1;
    }

    pub fn getIndex(self: *Self, comptime T: type, index: usize) !T {
        if (!self.checkType(T)) return error.TypeIncorrect;

        if (index >= self.len) {
            return error.IndexNotFound;
        }

        const sizeT = @sizeOf(T);
        const offset = sizeT * index;

        var dataBytes = self.data[offset..offset + sizeT];
        return mem.bytesToValue(T, @ptrCast(*[sizeT]u8, dataBytes));
    }

    pub fn getIndexPtr(self: *Self, comptime T: type, index: usize) !*T {
        if (!self.checkType(T)) return error.TypeIncorrect;

        if (index >= self.len) {
            return error.IndexNotFound;
        }

        const sizeT = @sizeOf(T);
        const offset = sizeT * index;

        var dataBytes = self.data[offset..offset + sizeT];
        return @ptrCast(*T, @alignCast(@alignOf(T), dataBytes));
    }

    pub fn setIndex(self: *Self, comptime T: type, index: usize, data: T) !void {
        if (!self.checkType(T)) return error.TypeIncorrect;

        if (index >= self.len) {
            return error.IndexNotFound;
        }

        const sizeT = @sizeOf(T);
        const offset = sizeT * index;

        const dataBytes = mem.toBytes(data);
        for (dataBytes[0..dataBytes.len]) |b, i| self.data[offset + i] = b;
    }
};

test "AnyVecStore" {
    warn("\n", .{});

    var store = try AnyVecStore.init(u32, std.heap.page_allocator);
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
}

pub const MultiVecStore = struct {
    const Self = @This();
    allocator: *Allocator,

    data: []u8,
    data_len: usize,

    offset_map: std.AutoHashMap(usize, usize),

    len: usize,

    pub fn init(allocator: *Allocator) !Self {
        return Self{
            .allocator = allocator,

            .data = &[_]u8{},
            .data_len = 0,

            .offset_map = std.AutoHashMap(usize, usize).init(allocator),

            .len = 0,
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

        _ = try self.offset_map.put(self.len, offset);

        self.data_len += sizeT;
        self.len += 1;
    }

    pub fn getIndex(self: *Self, comptime T: type, index: usize) !T {
        if (self.offset_map.get(index) == null) {
            return error.IndexNotFound;
        }

        const sizeT = @sizeOf(T);
        const offset = self.offset_map.get(index).?.value;

        var dataBytes = self.data[offset..offset + sizeT];
        return mem.bytesToValue(T, @ptrCast(*[sizeT]u8, dataBytes));
    }

    pub fn getIndexPtr(self: *Self, comptime T: type, index: usize) !*T {
        if (self.offset_map.get(index) == null) {
            return error.IndexNotFound;
        }

        const sizeT = @sizeOf(T);
        const offset = self.offset_map.get(index).?.value;

        var dataBytes = self.data[offset..offset + sizeT];
        return @ptrCast(*T, @alignCast(@alignOf(T), dataBytes));
    }

    pub fn setIndex(self: *Self, comptime T: type, index: usize, data: T) !void {
        if (self.offset_map.get(index) == null) {
            return error.IndexNotFound;
        }

        const sizeT = @sizeOf(T);
        const offset = self.offset_map.get(index).?.value;

        const dataBytes = mem.toBytes(data);
        for (dataBytes[0..dataBytes.len]) |b, i| self.data[offset + i] = b;
    }
};

test "MultiVecStore" {
    warn("\n", .{});

    const PositionComponent = struct {
        pos: [3]f32,
    };

    var store = try MultiVecStore.init(std.heap.page_allocator);
    defer store.deinit();

    try store.append(u32, 11111);
    try store.append(u32, 22222);
    try store.append(u32, 33333);
    try store.append(PositionComponent, PositionComponent{.pos = [3]f32{0.0, 0.0, 0.0}});
    try store.append(PositionComponent, PositionComponent{.pos = [3]f32{1.0, 1.0, 1.0}});
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
}