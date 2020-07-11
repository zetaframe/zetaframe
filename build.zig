const std = @import("std");
const Builder = std.build.Builder;

const zf = @import("pkg.zig").Pkg(".");
const vkgen = @import("render/lib/vulkan-zig/generator/index.zig");

const Example = struct { name: []const u8, path: []const u8, libs: u3 };

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

    const examples = [_]Example{
        .{ .name = "simple-core", .path = "examples/simple-core/main.zig", .libs = 0b110 },
        .{ .name = "simple-render", .path = "examples/simple-render/main.zig", .libs = 0b111 },
    };

    for (examples) |ex| {
        var exe = b.addExecutable(ex.name, ex.path);
        exe.setBuildMode(mode);
        exe.setTarget(target);

        if (ex.libs & 0b100 == 0b100) zf.addZetaModule(exe, .Core);
        if (ex.libs & 0b010 == 0b010) zf.addZetaModule(exe, .Math);
        if (ex.libs & 0b001 == 0b001) zf.addZetaModule(exe, .Render) else exe.linkLibC();

        const run = exe.run();
        const step = b.step(ex.name, b.fmt("run example {}", .{ex.name}));
        step.dependOn(&run.step);

        exe.install();
    }

    const gen_vk_bindings = vkgen.VkGenerateStep.init(b, "render/lib/vk.xml", "render/src/include/vk.zig");
    const gen_vk_step = b.step("generate-vk", "Generates vulkan bindings");
    gen_vk_step.dependOn(&gen_vk_bindings.step);
}
