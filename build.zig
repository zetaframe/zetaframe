const std = @import("std");
const Builder = std.build.Builder;

const zf = @import("pkg.zig").Pkg(".");

const Example = struct { name: []const u8, path: []const u8, libs: u3 };

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const valgrind = b.option(bool, "valgrind", "links libc for better valgrind support") orelse false;

    const core_test = b.addTest("core/test/test.zig");
    core_test.setBuildMode(mode);
    zf.addZetaModule(core_test, .Core);

    const math_test = b.addTest("math/test/test.zig");
    math_test.setBuildMode(mode);
    zf.addZetaModule(math_test, .Math);

    const render_test = b.addTest("render/test/test.zig");
    render_test.setBuildMode(mode);
    zf.addZetaModule(render_test, .Core);
    zf.addZetaModule(render_test, .Math);
    zf.addZetaModule(render_test, .Render);

    const test_step = b.step("test", "Run ALL tests");
    test_step.dependOn(&core_test.step);
    test_step.dependOn(&math_test.step);
    test_step.dependOn(&render_test.step);

    const test_only_render_step = b.step("test-only-render", "Run only render tests");
    test_only_render_step.dependOn(&render_test.step);

    const test_no_render_step = b.step("test-no-render", "Run all but render tests");
    test_no_render_step.dependOn(&core_test.step);
    test_no_render_step.dependOn(&math_test.step);

    const examples = [_]Example{
        .{ .name = "simple", .path = "examples/simple.zig", .libs = 0b110 },
    };

    for (examples) |ex| {
        var exe = b.addExecutable(ex.name, ex.path);
        exe.setBuildMode(mode);
        exe.setTarget(target);

        if (ex.libs & 0b100 == 0b100) zf.addZetaModule(exe, .Core);
        if (ex.libs & 0b010 == 0b010) zf.addZetaModule(exe, .Math);
        if (ex.libs & 0b001 == 0b001) zf.addZetaModule(exe, .Render) else if (valgrind) exe.linkLibC();

        const run = exe.run();
        const step = b.step(ex.name, b.fmt("run example {}", .{ex.name}));
        step.dependOn(&run.step);

        exe.install();
    }
}
