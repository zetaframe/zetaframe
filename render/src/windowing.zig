const std = @import("std");
const testing = std.testing;
const panic = std.debug.panic;

const glfw = @import("include/glfw.zig");

pub const WindowError = error{
    InitFailed,
    CreationFailed,
};

pub const Size = struct {
    width: u32,
    height: u32,
};

pub const Window = struct {
    window: *glfw.GLFWwindow,

    name: [*c]const u8,
    size: Size,

    pub fn new(name: [*c]const u8, windowSize: Size) Window {
        return Window{
            .window = undefined,

            .name = name,
            .size = windowSize,
        };
    }

    pub fn init(self: *Window) !void {
        _ = glfw.glfwSetErrorCallback(errorCallback);
        if (glfw.glfwInit() == glfw.GLFW_FALSE) {
            return WindowError.InitFailed;
        }

        glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);

        self.window = glfw.glfwCreateWindow(@intCast(c_int, self.size.width), @intCast(c_int, self.size.height), self.name, null, null) orelse {
            return WindowError.CreationFailed;
        };
    }

    pub fn deinit(self: Window) void {
        glfw.glfwDestroyWindow(self.window);
        glfw.glfwTerminate();
    }

    pub fn isRunning(self: *Window) bool {
        return (glfw.glfwWindowShouldClose(self.window) == glfw.GLFW_FALSE);
    }

    pub fn update(self: *Window) void {
        glfw.glfwPollEvents();
    }
};

//----- All Backends
fn errorCallback(err: c_int, description: [*c]const u8) callconv(.C) void {
    panic("Error: {}\n", .{description});
}

//----- Vulkan Specific
fn vulkanFramebufferSizeCallback(window: ?*glfw.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {

}