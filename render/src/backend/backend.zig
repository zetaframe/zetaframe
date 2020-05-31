const std = @import("std");

const Allocator = std.mem.Allocator;

const testing = std.testing;
const panic = std.debug.panic;

const windowing = @import("../windowing.zig");
const shader = @import("shader.zig");

pub const Shader = @import("shader.zig").Shader;

pub const Gpu = @import("gpu.zig").Gpu;
pub const RenderPass = @import("renderpass.zig").RenderPass;

pub const Pipeline = @import("pipeline.zig").Pipeline;

const swapchain = @import("swapchain.zig");
pub const Swapchain = swapchain.Swapchain;

pub const Command = @import("command.zig").Command;

pub const RenderCore = @import("rendercore.zig").RenderCore;

pub const buffer = @import("buffer.zig");

const vk = @import("../include/vk.zig");
const VK_SUCCESS = vk.Result.SUCCESS;

const vma = @import("../include/vma.zig");

const glfw = @import("../include/glfw.zig");

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

pub const VkBackend = struct {
    allocator: *Allocator,
    vallocator: vma.VmaAllocator,

    name: [*c]const u8,
    window: *windowing.Window,

    rendercore: RenderCore,

    instance: vk.Instance,
    gpu: Gpu,

    present_queue: vk.Queue,
    graphics_queue: vk.Queue,

    image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
    render_finished_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
    in_flight_fences: [MAX_FRAMES_IN_FLIGHT]vk.Fence,
    in_flight_images: []?vk.Fence,
    current_frame: usize = 0,

    pub fn new(allocator: *Allocator, name: [*c]const u8, window: *windowing.Window, rendercore: RenderCore) VkBackend {
        return VkBackend{
            .allocator = allocator,
            .vallocator = undefined,

            .name = name,
            .window = window,

            .rendercore = rendercore,

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

    pub fn init(self: *VkBackend) !void {
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

            .vulkanApiVersion = vk.API_VERSION_1_0,

            .pVulkanFunctions = null,

            .pRecordSettings = null,

            .flags = 0,
        };

        if(vma.vmaCreateAllocator(&allocInfo, &self.vallocator) != VK_SUCCESS) {
            return VulkanError.CreateAllocatorFailed;
        }

        try self.rendercore.init(self.allocator, &self.vallocator, false, self.gpu, self.window);
        
        try self.createSyncObjects();
    }

    pub fn deinit(self: *VkBackend) void {
        vk.DeviceWaitIdle(self.gpu.device) catch unreachable;

        self.rendercore.deinit(false);

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

    fn recreateSwapchain(self: *VkBackend) !void {
        try vk.DeviceWaitIdle(self.gpu.device);
        self.rendercore.deinit(true);

        try self.rendercore.init(self.allocator, &self.vallocator, true, self.gpu, self.window);
    }

    pub fn render(self: *VkBackend) !void {
        _ = try vk.WaitForFences(self.gpu.device, @ptrCast(*[1]vk.Fence, &self.in_flight_fences[self.current_frame]), vk.TRUE, std.math.maxInt(u64));

        var imageIndex: u32 = 0;
        var result = vk.vkAcquireNextImageKHR(self.gpu.device, self.rendercore.swapchain.swapchain, std.math.maxInt(u64), self.image_available_semaphores[self.current_frame], null, &imageIndex);
        if (result == .ERROR_OUT_OF_DATE_KHR) {
            try self.recreateSwapchain();
        } else if(result != VK_SUCCESS and result != .SUBOPTIMAL_KHR) {
            return VulkanError.AcquireImageFailed;
        }

        if (self.in_flight_images[imageIndex] != null) {
            std.debug.warn("\n{}\n", .{self.in_flight_images[imageIndex].?});
            _ = try vk.WaitForFences(self.gpu.device, @ptrCast(*[1]vk.Fence, &self.in_flight_images[imageIndex].?), vk.TRUE, std.math.maxInt(u64));

            self.in_flight_images[imageIndex] = self.in_flight_fences[self.current_frame];
        }

        var waitSemaphores = [_]vk.Semaphore{self.image_available_semaphores[self.current_frame]};
        var waitStages = [_]vk.PipelineStageFlags{vk.PipelineStageFlags{.colorAttachmentOutput = true}};
        const waitStageMask: [*]align(4) vk.PipelineStageFlags = @alignCast(4, &waitStages);

        const signalSemaphores = [_]vk.Semaphore{self.render_finished_semaphores[self.current_frame]};
        
        var submitInfos = [_]vk.SubmitInfo{vk.SubmitInfo{
            .waitSemaphoreCount = waitSemaphores.len,
            .pWaitSemaphores = &waitSemaphores,
            .pWaitDstStageMask = waitStageMask,

            .commandBufferCount = 1,
            .pCommandBuffers = &[_]vk.CommandBuffer{self.rendercore.command.command_buffers[imageIndex]},

            .signalSemaphoreCount = signalSemaphores.len,
            .pSignalSemaphores = &signalSemaphores,
        }};

        try vk.ResetFences(self.gpu.device, &[_]vk.Fence{self.in_flight_fences[self.current_frame]});

        if(vk.vkQueueSubmit(self.gpu.graphics_queue, submitInfos.len, &submitInfos, self.in_flight_fences[self.current_frame]) != VK_SUCCESS) {
            return VulkanError.SubmitBufferFailed;
        }

        const swapchains = [_]vk.SwapchainKHR{self.rendercore.swapchain.swapchain};
        const presentInfo = vk.PresentInfoKHR{
            .waitSemaphoreCount = signalSemaphores.len,
            .pWaitSemaphores = &signalSemaphores,

            .swapchainCount = swapchains.len,
            .pSwapchains = &swapchains,

            .pImageIndices = &[_]u32{imageIndex},
        };

        result = vk.vkQueuePresentKHR(self.gpu.present_queue, &presentInfo);
        if (result == .ERROR_OUT_OF_DATE_KHR) {
            try self.recreateSwapchain();
        } else if(result != VK_SUCCESS and result != .SUBOPTIMAL_KHR) {
            return VulkanError.PresentFailed;
        }

        self.current_frame = (self.current_frame + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    fn createInstance(self: *VkBackend) !void {
        if (enableValidationLayers and !(try checkValidationLayerSupport(self.allocator))) {
            return VulkanError.ValidationLayersNotAvailable;
        }

        const appInfo = vk.ApplicationInfo{
            .pApplicationName = self.name,
            .applicationVersion = vk.MAKE_VERSION(1, 0, 0),
            .pEngineName = "zetaframe",
            .engineVersion = vk.MAKE_VERSION(1, 0, 0),
            .apiVersion = vk.API_VERSION_1_0,
        };

        var glfwExtensionCount: u32 = 0;
        var glfwExtensions = glfw.glfwGetRequiredInstanceExtensions(&glfwExtensionCount);
        const extensions = glfwExtensions[0..glfwExtensionCount];

        const createInfo = vk.InstanceCreateInfo{
            .pApplicationInfo = &appInfo,
            .enabledExtensionCount = @intCast(u32, extensions.len),
            .ppEnabledExtensionNames = extensions.ptr,
            .enabledLayerCount = if (enableValidationLayers) @intCast(u32, validationLayers.len) else 0,
            .ppEnabledLayerNames = if (enableValidationLayers) &validationLayers else null,
        };

        self.instance = try vk.CreateInstance(createInfo, null);
    }

    fn createSyncObjects(self: *VkBackend) !void {
        const semaphoreInfo = vk.SemaphoreCreateInfo{};

        const fenceInfo = vk.FenceCreateInfo{
            .flags = vk.FenceCreateFlags{.signaled = true},
        };

        self.in_flight_images = try self.allocator.alloc(?vk.Fence, self.rendercore.swapchain.images.len);
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