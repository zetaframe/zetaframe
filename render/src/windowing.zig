const std = @import("std");
const testing = std.testing;
const panic = std.debug.panic;

const backend = @import("backend/backend.zig");

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
        _ = glfw.glfwSetErrorCallback(errorCallback);
        if (glfw.glfwInit() == glfw.GLFW_FALSE) {
            return WindowError.InitFailed;
        }

        switch (self.backend_type) {
            // .OpenGL => {
            //     //Target OpenGL 4.5
            //     glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 4);
            //     glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 5);

            //     //Core profile
            //     glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);

            //     //Needed for macos
            //     glfw.glfwWindowHint(glfw.GLFW_OPENGL_FORWARD_COMPAT, glfw.GL_TRUE);

            //     self.window = glfw.glfwCreateWindow(@intCast(c_int, self.size.width), @intCast(c_int, self.size.height), self.name, null, null) orelse {
            //         return WindowError.CreationFailed;
            //     };
                
            //     glfw.glfwMakeContextCurrent(self.window);

            //     glfw.glViewport(0, 0, @intCast(c_int, self.size.width), @intCast(c_int, self.size.height));

            //     _ = glfw.glfwSetFramebufferSizeCallback(self.window, openglFramebufferSizeCallback);
            // },
            .Vulkan => {
                //Don't load OpenGL
                glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);

                self.window = glfw.glfwCreateWindow(@intCast(c_int, self.size.width), @intCast(c_int, self.size.height), self.name, null, null) orelse {
                    return WindowError.CreationFailed;
                };
            },
            else => {},
        }
    }

    pub fn deinit(self: Window) void {
        switch(self.backend_type) {
            .OpenGL => {
                glfw.glfwDestroyWindow(self.window);
                glfw.glfwTerminate();
            },
            .Vulkan => {
                glfw.glfwDestroyWindow(self.window);
                glfw.glfwTerminate();
            },
            else => {
                glfw.glfwTerminate();
            }
        }
    }

    pub fn isRunning(self: *Window) bool {
        return (glfw.glfwWindowShouldClose(self.window) == glfw.GLFW_FALSE);
    }

    pub fn update(self: *Window) void {
        switch (self.backend_type) {
            .OpenGL => {
                glfw.glfwSwapBuffers(self.window);
                glfw.glfwPollEvents();
            },
            .Vulkan => {
                glfw.glfwPollEvents();
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
fn vulkanFramebufferSizeCallback(window: ?*glfw.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {

}

//----- OpenGL Specific
fn openglFramebufferSizeCallback(window: ?*glfw.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    glfw.glViewport(0, 0, width, height);
}