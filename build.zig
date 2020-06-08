const std = @import("std");
const Builder = std.build.Builder;

const zf = @import("pkg.zig");

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const core_test = b.addTest("core/test/test.zig");
    core_test.setBuildMode(mode);
    core_test.addPackage(zf.corepkg);

    const math_test = b.addTest("math/test/test.zig");
    math_test.setBuildMode(mode);
    math_test.addPackage(zf.mathpkg);

    const render_test = b.addTest("render/test/test.zig");
    render_test.setBuildMode(mode);
    render_test.addPackage(zf.corepkg);
    render_test.addPackage(zf.mathpkg);
    render_test.addPackage(zf.renderpkg);
    render_test.linkSystemLibrary("c");
    render_test.linkSystemLibrary("glfw");
    render_test.linkSystemLibrary("vulkan");
    render_test.linkSystemLibrary("c++");
    if (target.isLinux()) {
        render_test.addObjectFile("render/lib/vma/vma-linux.o");
    } else if (target.isWindows()) {
        render_test.addObjectFile("render/lib/vma/vma-windows.o");
    }

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
