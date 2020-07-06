const std = @import("std");
const Allocator = std.mem.Allocator;

const testing = std.testing;
const panic = std.debug.panic;

const vk = @import("../include/vk.zig");
const VK_SUCCESS = vk.Result.SUCCESS;
const vma = @import("../include/vma.zig");
const glfw = @import("../include/glfw.zig");

const windowing = @import("../windowing.zig");
const shader = @import("shader.zig");

// Re-exports
pub const Shader = @import("shader.zig").Shader;
pub const Gpu = @import("gpu.zig").Gpu;
pub const RenderPass = @import("renderpass.zig").RenderPass;
pub const Pipeline = @import("pipeline.zig").Pipeline;
pub const Swapchain = @import("swapchain.zig").Swapchain;
pub const Command = @import("command.zig").Command;
pub const buffer = @import("buffer.zig");
pub const Framebuffer = @import("framebuffer.zig").Framebuffer;
pub const ImageView = vk.ImageView;

pub const VulkanError = error{
    InstanceCreationFailed,

    LayerEnumerationFailed,
    ValidationLayersNotAvailable,

    CreateSurfaceFailed,

    DeviceEnumerationFailed,
    NoValidDevices,
    CreateDeviceFailed,

    ExtensionEnumerationFailed,

    QuerySwapchainSupportFailed,
    CreateSwapchainFailed,

    GetImagesFailed,

    CreateImageViewFailed,

    CreateShaderModuleFailed,

    CreatePipelineLayoutFailed,

    CreateRenderPassFailed,

    CreateGraphicsPipelineFailed,

    CreateFramebufferFailed,

    CreateCommandPoolFailed,

    AllocCommandBuffersFailed,
    BeginRecordCommandBufferFailed,
    RecordCommandBufferFailed,

    CreateSemaphoreFailed,
    CreateFenceFailed,

    AcquireImageFailed,

    SubmitBufferFailed,

    PresentFailed,

    CreateBufferFailed,

    CreateAllocatorFailed,

    MapMemoryFailed,
};

const enableValidationLayers = std.debug.runtime_safety;
const validationLayers = [_][*:0]const u8{"VK_LAYER_LUNARG_standard_validation"};
const deviceExtensions = [_][*:0]const u8{vk.VK_KHR_SWAPCHAIN_EXTENSION_NAME};
const MAX_FRAMES_IN_FLIGHT: u32 = 2;

// Vulkan Backend
pub const Backend = struct {
    const Self = @This();
    allocator: *Allocator,
    vallocator: vma.VmaAllocator,

    name: [*c]const u8,
    window: *windowing.Window,

    swapchain: Swapchain,
    render_pass: RenderPass,

    instance: vk.Instance,
    gpu: Gpu,

    present_queue: vk.Queue,
    graphics_queue: vk.Queue,

    image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
    render_finished_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
    in_flight_fences: [MAX_FRAMES_IN_FLIGHT]vk.Fence,
    in_flight_images: []?vk.Fence,
    current_frame: usize = 0,

    /// Create a new vulkan renderer backend with specified render core
    pub fn new(allocator: *Allocator, window: *windowing.Window, swapchain: Swapchain, renderPass: RenderPass) Self {
        return Self{
            .allocator = allocator,
            .vallocator = undefined,

            .name = window.name,
            .window = window,

            .swapchain = swapchain,
            .render_pass = renderPass,

            .instance = undefined,
            .gpu = undefined,

            .present_queue = undefined,
            .graphics_queue = undefined,

            .image_available_semaphores = undefined,
            .render_finished_semaphores = undefined,
            .in_flight_fences = undefined,
            .in_flight_images = undefined,
        };
    }

    pub fn init(self: *Self) !void {
        try self.createInstance();

        self.gpu = Gpu.new(self.instance, self.window);
        try self.gpu.init(self.allocator);

        const allocInfo = vma.VmaAllocatorCreateInfo{
            .physicalDevice = self.gpu.physical_device,
            .device = self.gpu.device,
            .instance = self.instance,

            .preferredLargeHeapBlockSize = 0,
            .pHeapSizeLimit = null,

            .pAllocationCallbacks = null,
            .pDeviceMemoryCallbacks = null,

            .frameInUseCount = MAX_FRAMES_IN_FLIGHT - 1,

            .vulkanApiVersion = vk.API_VERSION_1_1,

            .pVulkanFunctions = null,

            .pRecordSettings = null,

            .flags = 0,
        };

        if (vma.vmaCreateAllocator(&allocInfo, &self.vallocator) != VK_SUCCESS) {
            return VulkanError.CreateAllocatorFailed;
        }

        try self.swapchain.init(self.allocator, &self.gpu, self.window);
        try self.render_pass.init(&self.gpu, self.swapchain.image_format);

        try self.createSyncObjects();
    }

    pub fn deinit(self: *Self) void {
        vk.DeviceWaitIdle(self.gpu.device) catch unreachable;

        self.render_pass.deinit();
        self.swapchain.deinit();

        var i: usize = 0;
        while (i < MAX_FRAMES_IN_FLIGHT) : (i += 1) {
            vk.DestroySemaphore(self.gpu.device, self.render_finished_semaphores[i], null);
            vk.DestroySemaphore(self.gpu.device, self.image_available_semaphores[i], null);
            vk.DestroyFence(self.gpu.device, self.in_flight_fences[i], null);
        }

        self.allocator.free(self.in_flight_images);

        vma.vmaDestroyAllocator(self.vallocator);

        self.gpu.deinit();

        vk.DestroyInstance(self.instance, null);
    }

    fn recreateSwapchain(self: *Self, command: *Command) !void {
        try vk.DeviceWaitIdle(self.gpu.device);
        self.swapchain.deinit();

        try self.swapchain.init(self.allocator, &self.gpu, self.window);

        self.render_pass.deinit();
        try self.render_pass.init(&self.gpu, self.swapchain.image_format);

        command.pipeline.deinit();
        try command.pipeline.init(self.allocator, &self.gpu, &self.render_pass);

        for (command.framebuffers) |*fb, i| {
            fb.deinit();
            fb.* = try Framebuffer.init(&self.gpu, &[_]ImageView{self.swapchain.imageviews[i]}, &self.render_pass, &self.swapchain);
        }

        command.deinit();
        try command.init(self.allocator, &self.vallocator, &self.gpu, &self.render_pass, command.pipeline, self.swapchain.extent, command.framebuffers);
    }

    pub fn submit(self: *Self, command: *Command) !void {
        _ = try vk.WaitForFences(self.gpu.device, @ptrCast(*[1]vk.Fence, &self.in_flight_fences[self.current_frame]), vk.TRUE, std.math.maxInt(u64));

        var imageIndex: u32 = 0;
        if (try self.swapchain.acquireNextImage(self.image_available_semaphores[self.current_frame], &imageIndex)) try self.recreateSwapchain(command);

        if (self.in_flight_images[imageIndex] != null) {
            std.debug.warn("\n{}\n", .{self.in_flight_images[imageIndex].?});
            _ = try vk.WaitForFences(self.gpu.device, @ptrCast(*[1]vk.Fence, &self.in_flight_images[imageIndex].?), vk.TRUE, std.math.maxInt(u64));

            self.in_flight_images[imageIndex] = self.in_flight_fences[self.current_frame];
        }

        var waitSemaphores = [_]vk.Semaphore{self.image_available_semaphores[self.current_frame]};
        var waitStages = [_]vk.PipelineStageFlags{vk.PipelineStageFlags{ .colorAttachmentOutput = true }};
        const waitStageMask: [*]align(4) vk.PipelineStageFlags = @alignCast(4, &waitStages);

        const signalSemaphores = [_]vk.Semaphore{self.render_finished_semaphores[self.current_frame]};

        var submitInfos = [_]vk.SubmitInfo{vk.SubmitInfo{
            .waitSemaphoreCount = waitSemaphores.len,
            .pWaitSemaphores = &waitSemaphores,
            .pWaitDstStageMask = waitStageMask,

            .commandBufferCount = 1,
            .pCommandBuffers = &[_]vk.CommandBuffer{command.command_buffers[imageIndex]},

            .signalSemaphoreCount = signalSemaphores.len,
            .pSignalSemaphores = &signalSemaphores,
        }};

        try vk.ResetFences(self.gpu.device, &[_]vk.Fence{self.in_flight_fences[self.current_frame]});

        if (vk.vkQueueSubmit(self.gpu.graphics_queue, submitInfos.len, &submitInfos, self.in_flight_fences[self.current_frame]) != VK_SUCCESS) {
            return VulkanError.SubmitBufferFailed;
        }

        if (try self.swapchain.present(self.render_finished_semaphores[self.current_frame], imageIndex)) try self.recreateSwapchain(command);

        self.current_frame = (self.current_frame + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    fn createInstance(self: *Self) !void {
        if (enableValidationLayers and !(try checkValidationLayerSupport(self.allocator))) {
            return VulkanError.ValidationLayersNotAvailable;
        }

        const appInfo = vk.ApplicationInfo{
            .pApplicationName = self.name,
            .applicationVersion = vk.MAKE_VERSION(1, 0, 0),
            .pEngineName = "zetaframe",
            .engineVersion = vk.MAKE_VERSION(1, 0, 0),
            .apiVersion = vk.API_VERSION_1_1,
        };

        var glfwExtensionCount: u32 = 0;
        var glfwExtensions = glfw.glfwGetRequiredInstanceExtensions(&glfwExtensionCount);
        const extensions = glfwExtensions[0..glfwExtensionCount];

        const createInfo = vk.InstanceCreateInfo{
            .pApplicationInfo = &appInfo,
            .enabledExtensionCount = @intCast(u32, extensions.len),
            .ppEnabledExtensionNames = extensions.ptr,
            .enabledLayerCount = if (enableValidationLayers) @intCast(u32, validationLayers.len) else 0,
            .ppEnabledLayerNames = if (enableValidationLayers) &validationLayers else undefined,
        };

        self.instance = try vk.CreateInstance(createInfo, null);
    }

    fn createSyncObjects(self: *Self) !void {
        const semaphoreInfo = vk.SemaphoreCreateInfo{};

        const fenceInfo = vk.FenceCreateInfo{
            .flags = vk.FenceCreateFlags{ .signaled = true },
        };

        self.in_flight_images = try self.allocator.alloc(?vk.Fence, self.swapchain.images.len);
        for (self.in_flight_images) |fence, i| {
            self.in_flight_images[i] = null;
        }

        var i: usize = 0;
        while (i < MAX_FRAMES_IN_FLIGHT) : (i += 1) {
            self.image_available_semaphores[i] = try vk.CreateSemaphore(self.gpu.device, semaphoreInfo, null);
            self.render_finished_semaphores[i] = try vk.CreateSemaphore(self.gpu.device, semaphoreInfo, null);
            self.in_flight_fences[i] = try vk.CreateFence(self.gpu.device, fenceInfo, null);
        }
    }
};

fn checkValidationLayerSupport(allocator: *Allocator) !bool {
    var layerCount: u32 = 0;
    if (vk.vkEnumerateInstanceLayerProperties(&layerCount, null) != VK_SUCCESS) {
        return VulkanError.LayerEnumerationFailed;
    }

    const availableLayers = try allocator.alloc(vk.LayerProperties, layerCount);
    defer allocator.free(availableLayers);

    if (vk.vkEnumerateInstanceLayerProperties(&layerCount, availableLayers.ptr) != VK_SUCCESS) {
        return VulkanError.LayerEnumerationFailed;
    }

    for (validationLayers) |layerName| {
        var layerFound = false;

        for (availableLayers) |layerProperties| {
            if (std.cstr.cmp(layerName, @ptrCast([*c]const u8, &layerProperties.layerName)) == 0) {
                layerFound = true;
                break;
            }
        }

        if (!layerFound) {
            return false;
        }
    }

    return true;
}
