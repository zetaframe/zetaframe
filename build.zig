const std = @import("std");
const Builder = std.build.Builder;

const zf = @import("pkg.zig").Pkg(".");

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const core_test = b.addTest("core/test/test.zig");
    core_test.setBuildMode(mode);
    zf.addZetaModule(render_test, .Core);

    const math_test = b.addTest("math/test/test.zig");
    math_test.setBuildMode(mode);
    zf.addZetaModule(render_test, .Math);

    const render_test = b.addTest("render/test/test.zig");
    render_test.setBuildMode(mode);
    zf.addZetaModule(render_test, .Core);
    zf.addZetaModule(render_test, .Math);
    zf.addZetaModule(render_test, .Render);

    const test_step = b.step("test", "Run All tests");
    test_step.dependOn(&core_test.step);
    test_step.dependOn(&math_test.step);
    test_step.dependOn(&render_test.step);

    const test_only_render_step = b.step("test-only-render", "Run only render tests");
    test_only_render_step.dependOn(&render_test.step);

    const test_no_render_step = b.step("test-no-render", "Run all but render tests");
    test_no_render_step.dependOn(&core_test.step);
    test_no_render_step.dependOn(&math_test.step);
}
