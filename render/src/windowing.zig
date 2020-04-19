const std = @import("std");
const testing = std.testing;
const panic = std.debug.panic;

const backend = @import("backend/backend.zig");

const c = @import("c2.zig");

pub const WindowError = error{
    InitFailed,
    CreationFailed,
};

pub const Size = struct {
    width: u32,
    height: u32,
};

pub const Window = struct {
    window: *c.GLFWwindow,

    backend_type: backend.BackendType,

    name: [*c]const u8,
    size: Size,

    pub fn new(name: [*c]const u8, windowSize: Size, backendType: backend.BackendType) Window {
        return Window{
            .window = undefined,

            .backend_type = backendType,

            .name = name,
            .size = windowSize,
        };
    }

    pub fn init(self: *Window) !void {
        _ = c.glfwSetErrorCallback(errorCallback);
        if (c.glfwInit() == c.GLFW_FALSE) {
            return WindowError.InitFailed;
        }

        switch (self.backend_type) {
            .OpenGL => {
                //Target OpenGL 4.5
                c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 4);
                c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 5);

                //Core profile
                c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

                //Needed for macos
                c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);

                self.window = c.glfwCreateWindow(@intCast(c_int, self.size.width), @intCast(c_int, self.size.height), self.name, null, null) orelse {
                    return WindowError.CreationFailed;
                };
                
                c.glfwMakeContextCurrent(self.window);

                c.glViewport(0, 0, @intCast(c_int, self.size.width), @intCast(c_int, self.size.height));

                _ = c.glfwSetFramebufferSizeCallback(self.window, openglFramebufferSizeCallback);
            },
            .Vulkan => {
                //Don't load OpenGL
                c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);

                self.window = c.glfwCreateWindow(@intCast(c_int, self.size.width), @intCast(c_int, self.size.height), self.name, null, null) orelse {
                    return WindowError.CreationFailed;
                };
            },
            else => {},
        }
    }

    pub fn deinit(self: Window) void {
        switch(self.backend_type) {
            .OpenGL => {
                c.glfwDestroyWindow(self.window);
                c.glfwTerminate();
            },
            .Vulkan => {
                c.glfwDestroyWindow(self.window);
                c.glfwTerminate();
            },
            else => {
                c.glfwTerminate();
            }
        }
    }

    pub fn isRunning(self: *Window) bool {
        return (c.glfwWindowShouldClose(self.window) == c.GLFW_FALSE);
    }

    pub fn update(self: *Window) void {
        switch (self.backend_type) {
            .OpenGL => {
                c.glfwSwapBuffers(self.window);
                c.glfwPollEvents();
            },
            .Vulkan => {
                c.glfwPollEvents();
            },
            else => {},
        }
    }
};

//----- All Backends
fn errorCallback(err: c_int, description: [*c]const u8) callconv(.C) void {
    panic("Error: {}\n", .{description});
}

//----- Vulkan Specific
fn vulkanFramebufferSizeCallback(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {

}

//----- OpenGL Specific
fn openglFramebufferSizeCallback(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    c.glViewport(0, 0, width, height);
}