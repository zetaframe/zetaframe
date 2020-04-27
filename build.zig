const std = @import("std");
const Builder = std.build.Builder;

const zf = @import("pkg.zig");

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    //Testing
    const tests = b.addTest("test.zig");
    tests.setBuildMode(mode);

    tests.addPackage(zf.corepkg);
    tests.addPackage(zf.mathpkg);
    tests.addPackage(zf.renderpkg);

    tests.linkSystemLibrary("c");
    tests.linkSystemLibrary("epoxy");
    tests.linkSystemLibrary("glfw");
    tests.linkSystemLibrary("vulkan");

    tests.linkSystemLibrary("c++");
    tests.addObjectFile("render/lib/vma/vma.o");

    const test_step = b.step("test", "Run All tests");
    test_step.dependOn(&tests.step);
}
