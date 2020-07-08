const std = @import("std");
const LibExeObjStep = std.build.LibExeObjStep;
const Package = std.build.Pkg;

pub fn Pkg(zf_path: comptime []const u8) type {
    const zva = @import("render/lib/zva/pkg.zig").Pkg(zf_path ++ "/render/lib/zva", zf_path ++ "/render/src/include/vk.zig");

    return struct {
        pub const corepkg = Package{
            .name = "zetacore",
            .path = zf_path ++ "/core/src/lib.zig",
        };

        pub const mathpkg = Package{
            .name = "zetamath",
            .path = zf_path ++ "/math/src/lib.zig",
        };

        pub const renderpkg = Package{
            .name = "zetarender",
            .path = zf_path ++ "/render/src/lib.zig",
            .dependencies = &[_]Package{mathpkg, zva.pkg},
        };

        pub const Module = enum {
            Core,
            Math,
            Render,
        };

        pub fn addZetaModule(step: *LibExeObjStep, module: Module) void {
            switch (module) {
                .Core => {
                    step.addPackage(corepkg);
                },
                .Math => {
                    step.addPackage(mathpkg);
                },
                .Render => {
                    step.addPackage(renderpkg);

                    step.linkLibC();
                    step.linkSystemLibrary("glfw");
                    step.linkSystemLibrary("vulkan");
                },
            }
        }
    };
}
