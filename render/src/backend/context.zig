const std = @import("std");
const Allocator = std.mem.Allocator;

const vk = @import("../include/vk.zig");
const glfw = @import("../include/glfw.zig");

const windowing = @import("../windowing.zig");
const shader = @import("shader.zig");

const BackendError = @import("backend.zig").BackendError;

const enableValidationLayers = std.debug.runtime_safety;
const validationLayers = [_][*:0]const u8{"VK_LAYER_LUNARG_standard_validation"};
const deviceExtensions = [_][*:0]const u8{vk.extension_info.khr_swapchain.name};

const BaseDispatch = struct {
    vkCreateInstance: vk.PfnCreateInstance,
    vkEnumerateInstanceLayerProperties: vk.PfnEnumerateInstanceLayerProperties,

    usingnamespace vk.BaseWrapper(@This());
};

const InstanceDispatch = struct {
    vkDestroyInstance: vk.PfnDestroyInstance,
    vkDestroySurfaceKHR: vk.PfnDestroySurfaceKHR,

    vkCreateDevice: vk.PfnCreateDevice,

    vkEnumeratePhysicalDevices: vk.PfnEnumeratePhysicalDevices,
    vkGetPhysicalDeviceProperties: vk.PfnGetPhysicalDeviceProperties,
    vkGetPhysicalDeviceMemoryProperties: vk.PfnGetPhysicalDeviceMemoryProperties,
    vkGetPhysicalDeviceFeatures: vk.PfnGetPhysicalDeviceFeatures,
    vkEnumerateDeviceExtensionProperties: vk.PfnEnumerateDeviceExtensionProperties,
    vkGetPhysicalDeviceSurfaceFormatsKHR: vk.PfnGetPhysicalDeviceSurfaceFormatsKHR,
    vkGetPhysicalDeviceSurfacePresentModesKHR: vk.PfnGetPhysicalDeviceSurfacePresentModesKHR,
    vkGetPhysicalDeviceQueueFamilyProperties: vk.PfnGetPhysicalDeviceQueueFamilyProperties,
    vkGetPhysicalDeviceSurfaceSupportKHR: vk.PfnGetPhysicalDeviceSurfaceSupportKHR,
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR: vk.PfnGetPhysicalDeviceSurfaceCapabilitiesKHR,

    vkGetDeviceProcAddr: vk.PfnGetDeviceProcAddr,

    usingnamespace vk.InstanceWrapper(@This());
};

const DeviceDispatch = struct {
    vkDestroyDevice: vk.PfnDestroyDevice,
    vkGetDeviceQueue: vk.PfnGetDeviceQueue,
    vkDeviceWaitIdle: vk.PfnDeviceWaitIdle,

    vkCreateSemaphore: vk.PfnCreateSemaphore,
    vkDestroySemaphore: vk.PfnDestroySemaphore,

    vkCreateFence: vk.PfnCreateFence,
    vkDestroyFence: vk.PfnDestroyFence,
    vkWaitForFences: vk.PfnWaitForFences,
    vkResetFences: vk.PfnResetFences,

    vkCreateImageView: vk.PfnCreateImageView,
    vkDestroyImageView: vk.PfnDestroyImageView,

    vkCreateSwapchainKHR: vk.PfnCreateSwapchainKHR,
    vkDestroySwapchainKHR: vk.PfnDestroySwapchainKHR,

    vkGetSwapchainImagesKHR: vk.PfnGetSwapchainImagesKHR,
    vkAcquireNextImageKHR: vk.PfnAcquireNextImageKHR,

    vkQueueSubmit: vk.PfnQueueSubmit,
    vkQueuePresentKHR: vk.PfnQueuePresentKHR,
    vkQueueWaitIdle: vk.PfnQueueWaitIdle,

    vkCreateCommandPool: vk.PfnCreateCommandPool,
    vkDestroyCommandPool: vk.PfnDestroyCommandPool,

    vkAllocateCommandBuffers: vk.PfnAllocateCommandBuffers,
    vkFreeCommandBuffers: vk.PfnFreeCommandBuffers,

    vkCreateShaderModule: vk.PfnCreateShaderModule,
    vkDestroyShaderModule: vk.PfnDestroyShaderModule,

    vkCreatePipelineLayout: vk.PfnCreatePipelineLayout,
    vkDestroyPipelineLayout: vk.PfnDestroyPipelineLayout,

    vkCreateRenderPass: vk.PfnCreateRenderPass,
    vkDestroyRenderPass: vk.PfnDestroyRenderPass,

    vkCreateGraphicsPipelines: vk.PfnCreateGraphicsPipelines,
    vkDestroyPipeline: vk.PfnDestroyPipeline,

    vkCreateFramebuffer: vk.PfnCreateFramebuffer,
    vkDestroyFramebuffer: vk.PfnDestroyFramebuffer,

    vkBeginCommandBuffer: vk.PfnBeginCommandBuffer,
    vkEndCommandBuffer: vk.PfnEndCommandBuffer,

    vkAllocateMemory: vk.PfnAllocateMemory,
    vkFreeMemory: vk.PfnFreeMemory,
    vkMapMemory: vk.PfnMapMemory,
    vkUnmapMemory: vk.PfnUnmapMemory,

    vkCreateBuffer: vk.PfnCreateBuffer,
    vkDestroyBuffer: vk.PfnDestroyBuffer,
    vkGetBufferMemoryRequirements: vk.PfnGetBufferMemoryRequirements,
    vkBindBufferMemory: vk.PfnBindBufferMemory,

    vkCreateDescriptorSetLayout: vk.PfnCreateDescriptorSetLayout,
    vkDestroyDescriptorSetLayout: vk.PfnDestroyDescriptorSetLayout,

    vkCmdBeginRenderPass: vk.PfnCmdBeginRenderPass,
    vkCmdEndRenderPass: vk.PfnCmdEndRenderPass,
    vkCmdBindPipeline: vk.PfnCmdBindPipeline,
    vkCmdDrawIndexed: vk.PfnCmdDrawIndexed,
    vkCmdSetViewport: vk.PfnCmdSetViewport,
    vkCmdSetScissor: vk.PfnCmdSetScissor,
    vkCmdBindVertexBuffers: vk.PfnCmdBindVertexBuffers,
    vkCmdBindIndexBuffer: vk.PfnCmdBindIndexBuffer,
    vkCmdCopyBuffer: vk.PfnCmdCopyBuffer,

    usingnamespace vk.DeviceWrapper(@This());
};

pub const Context = struct {
    const Self = @This();
    allocator: *Allocator,

    vkb: BaseDispatch,
    vki: InstanceDispatch,
    vkd: DeviceDispatch,

    window: *windowing.Window,

    instance: vk.Instance,

    physical_device: vk.PhysicalDevice,
    properties: vk.PhysicalDeviceProperties,
    mem_properties: vk.PhysicalDeviceMemoryProperties,
    features: vk.PhysicalDeviceFeatures,

    indices: QueueFamilyIndices,

    device: vk.Device,
    surface: vk.SurfaceKHR,

    graphics_queue: vk.Queue,
    present_queue: vk.Queue,
    transfer_queue: vk.Queue,

    graphics_pool: vk.CommandPool,
    transfer_pool: vk.CommandPool,

    pub fn init(allocator: *Allocator, window: *windowing.Window) !Self {
        var self: Context = undefined;
        self.allocator = allocator;
        self.window = window;

        self.vkb = try BaseDispatch.load(glfw.glfwGetInstanceProcAddress);

        try self.createInstance();
        self.vki = try InstanceDispatch.load(self.instance, glfw.glfwGetInstanceProcAddress);
        errdefer self.vki.destroyInstance(self.instance, null);

        try self.createSurface();
        errdefer self.vki.destroySurfaceKHR(self.instance, self.surface, null);

        try self.pickPhysicalDevice();
        self.indices = try findQueueFamilies(self.allocator, self.vki, self.physical_device, self.surface);

        try self.createLogicalDevice();
        self.vkd = try DeviceDispatch.load(self.device, self.vki.vkGetDeviceProcAddr);
        errdefer self.vkd.destroyDevice(self.device, null);

        self.graphics_queue = self.vkd.getDeviceQueue(self.device, self.indices.graphics_family.?, 0);
        self.present_queue = self.vkd.getDeviceQueue(self.device, self.indices.present_family.?, 0);
        self.transfer_queue = self.vkd.getDeviceQueue(self.device, self.indices.transfer_family.?, 0);

        try self.createGraphicsPool();
        try self.createTransferPool();

        return self;
    }

    pub fn deinit(self: Self) void {
        self.vkd.destroyCommandPool(self.device, self.graphics_pool, null);
        self.vkd.destroyCommandPool(self.device, self.transfer_pool, null);

        self.vkd.destroyDevice(self.device, null);
        self.vki.destroySurfaceKHR(self.instance, self.surface, null);
        self.vki.destroyInstance(self.instance, null);
    }

    // Creates the vulkan instance
    fn createInstance(self: *Self) !void {
        // Check validation layer support if enabled
        if (enableValidationLayers and !(try checkValidationLayerSupport(self.vkb, self.allocator))) return BackendError.ValidationLayersNotAvailable;

        const appInfo = vk.ApplicationInfo{
            .p_application_name = self.window.name,
            .application_version = vk.makeVersion(0, 0, 0),
            .p_engine_name = "zetaframe",
            .engine_version = vk.makeVersion(0, 0, 0),
            .api_version = vk.API_VERSION_1_1,
        };

        var glfwExtensionCount: u32 = 0;
        const glfwExtensions = glfw.glfwGetRequiredInstanceExtensions(&glfwExtensionCount);

        // Call createInstance
        self.instance = try self.vkb.createInstance(.{
            .p_application_info = &appInfo,
            .enabled_extension_count = glfwExtensionCount,
            .pp_enabled_extension_names = @ptrCast([*]const [*:0]const u8, glfwExtensions),
            .enabled_layer_count = if (enableValidationLayers) @intCast(u32, validationLayers.len) else 0,
            .pp_enabled_layer_names = if (enableValidationLayers) &validationLayers else undefined,

            .flags = .{},
        }, null);
    }

    fn createSurface(self: *Self) !void {
        if (glfw.glfwCreateWindowSurface(self.instance, self.window.window, null, &self.surface) != vk.Result.success) {
            return BackendError.CreateSurfaceFailed;
        }
    }

    // Chooses a physicalDevice based on a calculated device score
    fn pickPhysicalDevice(self: *Self) !void {
        var deviceCount: u32 = 0;
        _ = try self.vki.enumeratePhysicalDevices(self.instance, &deviceCount, null);

        if (deviceCount == 0) return BackendError.NoValidDevices;

        const devices = try self.allocator.alloc(vk.PhysicalDevice, deviceCount);
        defer self.allocator.free(devices);

        _ = try self.vki.enumeratePhysicalDevices(self.instance, &deviceCount, devices.ptr);

        var deviceSelected = false;
        var selectedDevice: vk.PhysicalDevice = undefined;
        var selectedDeviceScore: u32 = 0;

        for (devices) |device| {
            var score = try calculateDeviceScore(self.allocator, self.vki, device, self.surface);
            if (score > selectedDeviceScore and score != 0) {
                deviceSelected = true;
                selectedDeviceScore = score;
                selectedDevice = device;
            }
        }

        if (!deviceSelected) return BackendError.NoValidDevices;

        self.physical_device = selectedDevice;

        self.properties = self.vki.getPhysicalDeviceProperties(self.physical_device);
        self.mem_properties = self.vki.getPhysicalDeviceMemoryProperties(self.physical_device);
        self.features = self.vki.getPhysicalDeviceFeatures(self.physical_device);

        std.log.info("Using Device: {}\n", .{self.properties.device_name});
    }

    // Creates the device from the physicalDevice
    fn createLogicalDevice(self: *Self) !void {
        var queueCreateInfos = std.ArrayList(vk.DeviceQueueCreateInfo).init(self.allocator);
        defer queueCreateInfos.deinit();

        var uniqueQueueFamilies: []u32 = undefined;
        if (self.indices.graphics_family.? == self.indices.present_family.?) {
            if (self.indices.graphics_family.? == self.indices.transfer_family.?) {
                uniqueQueueFamilies = &[_]u32{self.indices.graphics_family.?};
            } else {
                uniqueQueueFamilies = &[_]u32{ self.indices.graphics_family.?, self.indices.transfer_family.? };
            }
        } else {
            if (self.indices.present_family.? == self.indices.transfer_family.?) {
                uniqueQueueFamilies = &[_]u32{ self.indices.graphics_family.?, self.indices.present_family.? };
            } else {
                uniqueQueueFamilies = &[_]u32{ self.indices.graphics_family.?, self.indices.present_family.?, self.indices.transfer_family.? };
            }
        }

        var queuePriority: f32 = 1.0;
        for (uniqueQueueFamilies) |queueFamily| {
            const queueCreateInfo = vk.DeviceQueueCreateInfo{
                .queue_family_index = queueFamily,
                .queue_count = 1,
                .p_queue_priorities = &[_]f32{queuePriority},

                .flags = .{},
            };
            try queueCreateInfos.append(queueCreateInfo);
        }

        const createInfo = vk.DeviceCreateInfo{
            .queue_create_info_count = @intCast(u32, queueCreateInfos.items.len),
            .p_queue_create_infos = queueCreateInfos.items.ptr,

            .p_enabled_features = null,

            .enabled_extension_count = @intCast(u32, deviceExtensions.len),
            .pp_enabled_extension_names = &deviceExtensions,

            .enabled_layer_count = if (enableValidationLayers) @intCast(u32, validationLayers.len) else 0,
            .pp_enabled_layer_names = if (enableValidationLayers) &validationLayers else undefined,

            .flags = .{},
        };

        self.device = try self.vki.createDevice(self.physical_device, createInfo, null);
    }

    fn createGraphicsPool(self: *Self) !void {
        const indices = self.indices;

        const poolInfo = vk.CommandPoolCreateInfo{
            .queue_family_index = indices.graphics_family.?,

            .flags = .{
                .transient_bit = true,
                .reset_command_buffer_bit = true,
            },
        };

        self.graphics_pool = try self.vkd.createCommandPool(self.device, poolInfo, null);
    }

    fn createTransferPool(self: *Self) !void {
        const indices = self.indices;

        const poolInfo = vk.CommandPoolCreateInfo{
            .queue_family_index = indices.transfer_family.?,

            .flags = .{},
        };

        self.transfer_pool = try self.vkd.createCommandPool(self.device, poolInfo, null);
    }
};

// Checks validation layer support
fn checkValidationLayerSupport(vkb: BaseDispatch, allocator: *Allocator) !bool {
    var layerCount: u32 = 0;
    _ = try vkb.enumerateInstanceLayerProperties(&layerCount, null);

    const availableLayers = try allocator.alloc(vk.LayerProperties, layerCount);
    defer allocator.free(availableLayers);

    _ = try vkb.enumerateInstanceLayerProperties(&layerCount, availableLayers.ptr);

    for (validationLayers) |layerName| {
        var layerFound = false;

        for (availableLayers) |layerProperties| {
            if (std.cstr.cmp(layerName, @ptrCast([*c]const u8, &layerProperties.layer_name)) == 0) {
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

// Calculates pdevice score based on a number of factors
fn calculateDeviceScore(allocator: *Allocator, vki: InstanceDispatch, pdevice: vk.PhysicalDevice, surface: vk.SurfaceKHR) !u32 {
    var deviceProperties = vki.getPhysicalDeviceProperties(pdevice);
    var deviceMemProperties = vki.getPhysicalDeviceMemoryProperties(pdevice);
    var deviceFeatures = vki.getPhysicalDeviceFeatures(pdevice);

    var score: u32 = 0;

    if (deviceProperties.device_type == .discrete_gpu) {
        score += 4200;
    }

    score += @intCast(u32, deviceProperties.limits.max_image_dimension_2d);
    score += @intCast(u32, deviceMemProperties.memory_heap_count);

    //----- Must Haves
    if (deviceFeatures.geometry_shader == 0) return 0;
    if (!(try findQueueFamilies(allocator, vki, pdevice, surface)).isComplete()) return 0;
    if (!try checkDeviceExtensionSupport(allocator, vki, pdevice)) return 0;
    if (!try checkSwapchainSupport(vki, pdevice, surface)) return 0;

    std.log.debug("Device: {}, Type: {}, Score: {}\n", .{ deviceProperties.device_name, deviceProperties.device_type, score });

    return score;
}

const QueueFamilyIndices = struct {
    graphics_family: ?u32,
    present_family: ?u32,
    transfer_family: ?u32,

    fn init() QueueFamilyIndices {
        return QueueFamilyIndices{
            .graphics_family = null,
            .present_family = null,
            .transfer_family = null,
        };
    }

    fn isComplete(self: QueueFamilyIndices) bool {
        return self.graphics_family != null and self.present_family != null and self.transfer_family != null;
    }
};

fn findQueueFamilies(allocator: *Allocator, vki: InstanceDispatch, device: vk.PhysicalDevice, surface: vk.SurfaceKHR) !QueueFamilyIndices {
    var indices = QueueFamilyIndices.init();

    var queueFamilyCount: u32 = 0;
    vki.getPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, null);

    const queueFamilies = try allocator.alloc(vk.QueueFamilyProperties, queueFamilyCount);
    defer allocator.free(queueFamilies);

    vki.getPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queueFamilies.ptr);

    var i: u32 = 0;
    for (queueFamilies) |queueFamily| {
        if (queueFamily.queue_count < 0) {
            continue;
        }

        if (queueFamily.queue_flags.graphics_bit) {
            indices.graphics_family = i;
        }
        if (queueFamily.queue_flags.transfer_bit) {
            indices.transfer_family = i;
        }

        if ((try vki.getPhysicalDeviceSurfaceSupportKHR(device, i, surface)) == vk.TRUE) {
            indices.present_family = i;
        }

        if (indices.isComplete()) {
            break;
        }

        i += 1;
    }

    return indices;
}

// Checks the extensions that the pdevice supports
fn checkDeviceExtensionSupport(allocator: *Allocator, vki: InstanceDispatch, pdevice: vk.PhysicalDevice) !bool {
    var count: u32 = 0;
    _ = try vki.enumerateDeviceExtensionProperties(pdevice, null, &count, null);

    const availableExtensions = try allocator.alloc(vk.ExtensionProperties, count);
    defer allocator.free(availableExtensions);

    _ = try vki.enumerateDeviceExtensionProperties(pdevice, null, &count, availableExtensions.ptr);

    for (deviceExtensions) |deviceExt| {
        for (availableExtensions) |extension| {
            if (std.cstr.cmp(deviceExt, @ptrCast([*c]const u8, &extension.extension_name)) == 0) {
                break;
            }
        } else {
            return false;
        }
    }
    return true;
}

// Checks pdevice's swapchain support
fn checkSwapchainSupport(vki: InstanceDispatch, pdevice: vk.PhysicalDevice, surface: vk.SurfaceKHR) !bool {
    var formatCount: u32 = 0;
    _ = try vki.getPhysicalDeviceSurfaceFormatsKHR(pdevice, surface, &formatCount, null);

    var presentModeCount: u32 = 0;
    _ = try vki.getPhysicalDeviceSurfacePresentModesKHR(pdevice, surface, &presentModeCount, null);

    return formatCount > 0 and presentModeCount > 0;
}
