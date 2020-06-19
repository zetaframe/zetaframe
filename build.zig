const std = @import("std");
const Builder = std.build.Builder;

const zf = @import("pkg.zig").Pkg(".");

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

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

    const examples = [_][2][]const u8{
        [_][]const u8{ "simple", "examples/simple.zig" },
    };

    for (examples) |ex| {
        var exe = b.addExecutable(ex[0], ex[1]);
        exe.setBuildMode(mode);
        exe.setTarget(target);

        zf.addZetaModule(exe, .Core);
        zf.addZetaModule(exe, .Math);
        zf.addZetaModule(exe, .Render);

        const run = exe.run();
        const step = b.step(ex[0], b.fmt("run example {}", .{ex[0]}));
        step.dependOn(&run.step);

        exe.install();
    }
}
