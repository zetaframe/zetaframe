const std = @import("std");
const Builder = std.build.Builder;
const Package = std.build.Pkg;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    //Core
    const corepkg = Package{
        .name = "zetacore",
        .path = "core/src/lib.zig",
    };

    //Math
    const mathpkg = Package{
        .name = "zetamath",
        .path = "math/src/lib.zig",
    };

    //Render
    const renderpkg = Package{
        .name = "zetarender",
        .path = "render/src/lib.zig",
        .dependencies = &[_]Package{mathpkg},
    };

    //Testing
    const tests = b.addTest("test.zig");
    tests.setBuildMode(mode);

    tests.addPackage(corepkg);
    tests.addPackage(mathpkg);
    tests.addPackage(renderpkg);

    tests.linkSystemLibrary("c");
    tests.linkSystemLibrary("epoxy");
    tests.linkSystemLibrary("glfw");
    tests.linkSystemLibrary("vulkan");

    tests.linkSystemLibrary("c++");
    tests.addObjectFile("render/lib/vma/vma.o");

    const test_step = b.step("test", "Run All tests");
    test_step.dependOn(&tests.step);
}
