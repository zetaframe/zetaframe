const std = @import("std");

const vk = @import("../include/vk.zig");
const spv = @import("../include/spirv.zig");

const BackendError = @import("backend.zig").BackendError;

pub const Shader = struct {
    const Reflection = struct {
        const DescriptorSet = struct {
            const Binding = struct {
                binding: u32,

                kind: vk.DescriptorType,
            };

            bindings: std.ArrayList(Binding),
        };

        stage: vk.ShaderStageFlags,

        descriptor_sets: [3]DescriptorSet,

        local_size_x: u32,
        local_size_y: u32,
        local_size_z: u32,

        fn init(allocator: *std.mem.Allocator) Reflection {
            var refl: Shader.Reflection = undefined;

            for (refl.descriptor_sets) |*set| {
                set.bindings = std.ArrayList(DescriptorSet.Binding).init(allocator);
            }

            return refl;
        }

        fn deinit(self: Reflection) void {
            for (self.descriptor_sets) |set| {
                set.bindings.deinit();
            }
        }
    };

    const Self = @This();
    allocator: *std.mem.Allocator,

    from_file: bool,
    bytes: [:0]align(@alignOf(u32)) const u8,

    refl: Reflection,

    pub fn init(allocator: *std.mem.Allocator, filepath: []const u8) !Self {
        const bytes = try std.fs.cwd().readFileAllocOptions(allocator, filepath, std.math.maxInt(u32), @alignOf(u32), 0);

        return Self{
            .allocator = allocator,

            .from_file = true,
            .bytes = bytes,

            .refl = try parse(allocator, std.mem.bytesAsSlice(u32, bytes)),
        };
    }

    pub fn initBytes(allocator: *std.mem.Allocator, bytes: [:0]align(@alignOf(u32)) const u8) !Self {
        return Self{
            .allocator = undefined,

            .from_file = false,
            .bytes = bytes,

            .refl = try parse(allocator, std.mem.bytesAsSlice(u32, bytes)),
        };
    }

    pub fn deinit(self: Self) void {
        if (self.from_file) self.allocator.free(self.bytes);
        self.refl.deinit();
    }
};

fn parse(allocator: *std.mem.Allocator, code: []const u32) !Shader.Reflection {
    if (code[0] != spv.SpvMagicNumber) return BackendError.InvalidShader;

    var refl = Shader.Reflection.init(allocator);

    const Id = struct {
        opcode: u16,
        set: u32,
        binding: u32,
        id: u32,
        class: u32,
    };

    var ids = try allocator.alloc(Id, code[3]);

    var i: usize = 5;
    while (i < code.len) {
        var opcode = @truncate(u16, code[i]);
        var wordCount = @truncate(u16, code[i] >> 16);

        switch (opcode) {
            spv.SpvOpEntryPoint => {
                if (wordCount < 2) return BackendError.InvalidShader;
                refl.stage = switch (code[i + 1]) {
                    spv.SpvExecutionModelVertex => vk.ShaderStageFlags{ .vertex_bit = true },
                    spv.SpvExecutionModelFragment => vk.ShaderStageFlags{ .fragment_bit = true },
                    spv.SpvExecutionModelGLCompute => vk.ShaderStageFlags{ .compute_bit = true },
                    else => return BackendError.InvalidShader,
                };
            },
            spv.SpvOpExecutionMode => {
                if (wordCount < 3) return BackendError.InvalidShader;
                if (code[i + 2] == spv.SpvExecutionModeLocalSize) {
                    if (wordCount < 6) return BackendError.InvalidShader;
                    refl.local_size_x = code[i + 3];
                    refl.local_size_y = code[i + 4];
                    refl.local_size_z = code[i + 5];
                }
            },
            spv.SpvOpDecorate => {
                if (wordCount < 3) return BackendError.InvalidShader;

                switch (code[i + 2]) {
                    spv.SpvDecorationDescriptorSet => {
                        if (wordCount < 4) return BackendError.InvalidShader;
                        ids[code[i + 1]].set = code[i + 3];
                    },
                    spv.SpvDecorationBinding => {
                        if (wordCount < 4) return BackendError.InvalidShader;
                        ids[code[i + 1]].binding = code[i + 3];
                    },
                    else => {},
                }
            },
            spv.SpvOpTypePointer => {
                if (wordCount < 4) return BackendError.InvalidShader;

                ids[code[i + 1]].opcode = opcode;
                ids[code[i + 1]].id = code[i + 3];
                ids[code[i + 1]].class = code[i + 2];
            },
            spv.SpvOpVariable => {
                if (wordCount < 4) return BackendError.InvalidShader;

                ids[code[i + 2]].opcode = opcode;
                ids[code[i + 2]].id = code[i + 1];
                ids[code[i + 2]].class = code[i + 3];
            },
            spv.SpvOpTypeStruct, spv.SpvOpTypeImage => {
                if (wordCount < 2) return BackendError.InvalidShader;

                ids[code[i + 1]].opcode = opcode;
            },
            else => {},
        }

        std.debug.assert(i + wordCount <= code.len);

        i += wordCount;
    }

    for (ids) |id| {
        if (id.opcode == spv.SpvOpVariable) {
            switch (id.class) {
                spv.SpvStorageClassUniform, spv.SpvStorageClassUniformConstant => {
                    if (ids[ids[id.id].id].opcode == spv.SpvOpTypeStruct) {
                        try refl.descriptor_sets[id.set].bindings.append(.{
                            .binding = id.binding,

                            .kind = .uniform_buffer,
                        });
                    } else return BackendError.UnknownResourceType;
                },
                spv.SpvStorageClassStorageBuffer => {
                    switch (ids[ids[id.id].id].opcode) {
                        spv.SpvOpTypeStruct => {
                            try refl.descriptor_sets[id.set].bindings.append(.{
                                .binding = id.binding,

                                .kind = .storage_buffer,
                            });
                        },
                        spv.SpvOpTypeImage => {
                            try refl.descriptor_sets[id.set].bindings.append(.{
                                .binding = id.binding,

                                .kind = .storage_image,
                            });
                        },
                        else => return BackendError.UnknownResourceType,
                    }
                },
                else => {},
            }
        }
    }

    allocator.free(ids);

    return refl;
}
