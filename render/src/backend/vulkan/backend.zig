const std = @import("std");

const Allocator = std.mem.Allocator;


const testing = std.testing;
const panic = std.debug.panic;

const windowing = @import("../../windowing.zig");
const backend = @import("../backend.zig");

pub const Gpu = @import("gpu.zig").Gpu;
pub const RenderPass = @import("renderpass.zig").RenderPass;
pub const Pipeline = @import("pipeline.zig").Pipeline;
const swapchain = @import("swapchain.zig");
pub const Swapchain = swapchain.Swapchain;
pub const Command = @import("command.zig").Command;
pub const RenderCore = @import("rendercore.zig").RenderCore;

pub const buffer = @import("buffer.zig");

const c = @import("../../c2.zig");
const VK_SUCCESS = c.enum_VkResult.VK_SUCCESS;

const vma = @import("../../vma.zig");

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

    BindMemoryFailed,
};

const enableValidationLayers = std.debug.runtime_safety;
const validationLayers = [_][*c]const u8{"VK_LAYER_LUNARG_standard_validation"};
const deviceExtensions = [_][*c]const u8{c.VK_KHR_SWAPCHAIN_EXTENSION_NAME};
const MAX_FRAMES_IN_FLIGHT: u32 = 2;

pub const VkBackend = struct {
    allocator: *Allocator,
    vallocator: vma.VmaAllocator,

    name: [*c]const u8,
    window: *windowing.Window,

    rendercore: RenderCore,

    instance: c.VkInstance,
    gpu: Gpu,

    present_queue: c.VkQueue,
    graphics_queue: c.VkQueue,

    image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]c.VkSemaphore,
    render_finished_semaphores: [MAX_FRAMES_IN_FLIGHT]c.VkSemaphore,
    in_flight_fences: [MAX_FRAMES_IN_FLIGHT]c.VkFence,
    in_flight_images: []?c.VkFence,
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

            .vulkanApiVersion = c.VK_API_VERSION_1_0,

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
        _ = c.vkDeviceWaitIdle(self.gpu.device);

        self.rendercore.deinit(false);

        var i: usize = 0;
        while (i < MAX_FRAMES_IN_FLIGHT) : (i += 1) {
            c.vkDestroySemaphore(self.gpu.device, self.render_finished_semaphores[i], null);
            c.vkDestroySemaphore(self.gpu.device, self.image_available_semaphores[i], null);
            c.vkDestroyFence(self.gpu.device, self.in_flight_fences[i], null);
        }

        self.allocator.free(self.in_flight_images);

        vma.vmaDestroyAllocator(self.vallocator);   

        self.gpu.deinit();  

        c.vkDestroyInstance(self.instance, null);
    }

    fn recreateSwapchain(self: *VkBackend) !void {
        _ = c.vkDeviceWaitIdle(self.gpu.device);
        self.rendercore.deinit(true);

        try self.rendercore.init(self.allocator, &self.vallocator, true, self.gpu, self.window);
    }

    pub fn render(self: *VkBackend) !void {
        if(c.vkWaitForFences(self.gpu.device, 1, &self.in_flight_fences[self.current_frame], c.VK_TRUE, std.math.maxInt(u64)) != VK_SUCCESS) {
            return error.Unexpected;
        }

        var imageIndex: u32 = 0;
        var result = c.vkAcquireNextImageKHR(self.gpu.device, self.rendercore.swapchain.swapchain, std.math.maxInt(u64), self.image_available_semaphores[self.current_frame], null, &imageIndex);
        if (result == c.enum_VkResult.VK_ERROR_OUT_OF_DATE_KHR) {
            try self.recreateSwapchain();
        } else if(result != VK_SUCCESS and result != c.enum_VkResult.VK_SUBOPTIMAL_KHR) {
            return VulkanError.AcquireImageFailed;
        }

        if (self.in_flight_images[imageIndex] != null) {
            if(c.vkWaitForFences(self.gpu.device, 1, &self.in_flight_images[imageIndex].?, c.VK_TRUE, std.math.maxInt(u64)) != VK_SUCCESS) {
                return error.Unexpected;
            }

            self.in_flight_images[imageIndex] = self.in_flight_fences[self.current_frame];
        }

        var waitSemaphores = [_]c.VkSemaphore{self.image_available_semaphores[self.current_frame]};
        var waitStages = [_]c.VkPipelineStageFlags{c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};

        const signalSemaphores = [_]c.VkSemaphore{self.render_finished_semaphores[self.current_frame]};
        
        var submitInfos = [_]c.VkSubmitInfo{c.VkSubmitInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_SUBMIT_INFO,

            .waitSemaphoreCount = waitSemaphores.len,
            .pWaitSemaphores = &waitSemaphores,
            .pWaitDstStageMask = &waitStages,

            .commandBufferCount = 1,
            .pCommandBuffers = &self.rendercore.command.command_buffers[imageIndex],

            .signalSemaphoreCount = signalSemaphores.len,
            .pSignalSemaphores = &signalSemaphores,

            .pNext = null,
        }};

        if(c.vkResetFences(self.gpu.device, 1, &self.in_flight_fences[self.current_frame]) != VK_SUCCESS) {
            return error.Unexpected;
        }

        if(c.vkQueueSubmit(self.gpu.graphics_queue, submitInfos.len, &submitInfos, self.in_flight_fences[self.current_frame]) != VK_SUCCESS) {
            return VulkanError.SubmitBufferFailed;
        }

        const swapchains = [_]c.VkSwapchainKHR{self.rendercore.swapchain.swapchain};
        const presentInfo = c.VkPresentInfoKHR{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,

            .waitSemaphoreCount = signalSemaphores.len,
            .pWaitSemaphores = &signalSemaphores,

            .swapchainCount = swapchains.len,
            .pSwapchains = &swapchains,

            .pImageIndices = &imageIndex,

            .pResults = null,

            .pNext = null,
        };

        result = c.vkQueuePresentKHR(self.gpu.present_queue, &presentInfo);
        if (result == c.enum_VkResult.VK_ERROR_OUT_OF_DATE_KHR) {
            try self.recreateSwapchain();
        } else if(result != VK_SUCCESS and result != c.enum_VkResult.VK_SUBOPTIMAL_KHR) {
            return VulkanError.PresentFailed;
        }

        self.current_frame = (self.current_frame + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    fn createInstance(self: *VkBackend) !void {
        if (enableValidationLayers and !(try checkValidationLayerSupport(self.allocator))) {
            return VulkanError.ValidationLayersNotAvailable;
        }

        const appInfo = c.VkApplicationInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pApplicationName = self.name,
            .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "No Engine",
            .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = c.VK_API_VERSION_1_0,
            .pNext = null,
        };

        var glfwExtensionCount: u32 = 0;
        var glfwExtensions: [*c]const [*c]const u8 = c.glfwGetRequiredInstanceExtensions(&glfwExtensionCount);

        var extensionsList = std.ArrayList([*c]const u8).init(self.allocator);
        defer extensionsList.deinit();

        try extensionsList.appendSlice(glfwExtensions[0..glfwExtensionCount]);

        var extensions = extensionsList.toOwnedSlice();

        const createInfo = c.VkInstanceCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pApplicationInfo = &appInfo,
            .enabledExtensionCount = @intCast(u32, extensions.len),
            .ppEnabledExtensionNames = extensions.ptr,
            .enabledLayerCount = if (enableValidationLayers) @intCast(u32, validationLayers.len) else 0,
            .ppEnabledLayerNames = if (enableValidationLayers) &validationLayers else null,
            .pNext = null,
            .flags = 0,
        };

        if (c.vkCreateInstance(&createInfo, null, &self.instance) != VK_SUCCESS) {
            return VulkanError.InstanceCreationFailed;
        }
    }

    fn createSyncObjects(self: *VkBackend) !void {
        const semaphoreInfo = c.VkSemaphoreCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,

            .pNext = null,
            .flags = 0,
        };

        const fenceInfo = c.VkFenceCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,

            .pNext = null,
            .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
        };

        self.in_flight_images = try self.allocator.alloc(?c.VkFence, self.rendercore.swapchain.images.len);

        var i: usize = 0;
        while (i < MAX_FRAMES_IN_FLIGHT) : (i += 1) {
            if (c.vkCreateSemaphore(self.gpu.device, &semaphoreInfo, null, &self.image_available_semaphores[i]) != VK_SUCCESS) {
                return VulkanError.CreateSemaphoreFailed;
            }
            if (c.vkCreateSemaphore(self.gpu.device, &semaphoreInfo, null, &self.render_finished_semaphores[i]) != VK_SUCCESS) {
                return VulkanError.CreateSemaphoreFailed;
            }
            if(c.vkCreateFence(self.gpu.device, &fenceInfo, null, &self.in_flight_fences[i]) != VK_SUCCESS) {
                return VulkanError.CreateFenceFailed;
            }
        }
    }
};

fn checkValidationLayerSupport(allocator: *Allocator) !bool {
    var layerCount: u32 = 0;
    if (c.vkEnumerateInstanceLayerProperties(&layerCount, null) != VK_SUCCESS) {
        return VulkanError.LayerEnumerationFailed;
    }

    const availableLayers = try allocator.alloc(c.VkLayerProperties, layerCount);
    defer allocator.free(availableLayers);

    if (c.vkEnumerateInstanceLayerProperties(&layerCount, availableLayers.ptr) != VK_SUCCESS) {
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