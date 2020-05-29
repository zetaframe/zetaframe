const std = @import("std");
const Builder = std.build.Builder;

const zf = @import("pkg.zig");

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const tests = b.addTest("test.zig");
    tests.setTarget(target);
    tests.setBuildMode(mode);

    tests.addPackage(zf.corepkg);
    tests.addPackage(zf.mathpkg);
    tests.addPackage(zf.renderpkg);

    tests.linkSystemLibrary("c");
    tests.linkSystemLibrary("glfw");
    tests.linkSystemLibrary("vulkan");

    tests.linkSystemLibrary("c++");

    if (target.isLinux()) {
        tests.addObjectFile("render/lib/vma/vma-linux.o");
    } else if (target.isWindows()) {
        tests.addObjectFile("render/lib/vma/vma-windows.o");
    }

    const test_step = b.step("test", "Run All tests");
    test_step.dependOn(&tests.step);

    const tests_no_render = b.addTest("test.zig");
    tests_no_render.setBuildMode(mode);

    tests_no_render.setFilter("0");

    tests_no_render.addPackage(zf.corepkg);
    tests_no_render.addPackage(zf.mathpkg);

    const test_no_render = b.step("test-no-render", "Run all but render tests");
    test_no_render.dependOn(&tests_no_render.step);
}
