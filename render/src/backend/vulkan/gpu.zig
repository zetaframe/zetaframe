const std = @import("std");

const Allocator = std.mem.Allocator;

const c = @import("../../c2.zig");
const VK_SUCCESS = c.enum_VkResult.VK_SUCCESS;

const windowing = @import("../../windowing.zig");

const backend = @import("../backend.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const swapchain = @import("swapchain.zig");

const enableValidationLayers = std.debug.runtime_safety;
const validationLayers = [_][*c]const u8{"VK_LAYER_LUNARG_standard_validation"};
const deviceExtensions = [_][*c]const u8{c.VK_KHR_SWAPCHAIN_EXTENSION_NAME};

const QueueFamilyIndices = struct {
    graphics_family: ?u32,
    present_family: ?u32,

    fn init() QueueFamilyIndices {
        return QueueFamilyIndices{
            .graphics_family = null,
            .present_family = null,
        };
    }

    fn isComplete(self: QueueFamilyIndices) bool {
        return self.graphics_family != null and self.present_family != null;
    }
};

pub const Gpu = struct {
    const Self = @This();
    allocator: *Allocator,

    instance: c.VkInstance,
    window: *windowing.Window,

    indices: QueueFamilyIndices,

    physical_device: c.VkPhysicalDevice,
    device: c.VkDevice,
    surface: c.VkSurfaceKHR,

    graphics_queue: c.VkQueue,
    present_queue: c.VkQueue,

    pub fn new(instance: c.VkInstance, window: *windowing.Window) Self {
        return Self{
            .allocator = undefined,

            .instance = instance,
            .window = window,

            .indices = undefined,

            .physical_device = undefined,
            .device = undefined,
            .surface = undefined,

            .graphics_queue = undefined,
            .present_queue = undefined,
        };
    }

    pub fn init(self: *Self, allocator: *Allocator) !void {
        self.allocator = allocator;
        
        try self.createSurface();
        try self.pickPhysicalDevice();

        self.indices = try findQueueFamilies(self.allocator, self.physical_device, self.surface);

        try self.createLogicalDevice();
    }

    pub fn deinit(self: Self) void {
        c.vkDestroyDevice(self.device, null);

        c.vkDestroySurfaceKHR(self.instance, self.surface, null);
    }

    fn createSurface(self: *Self) !void {
        if (c.glfwCreateWindowSurface(self.instance, self.window.window, null, &self.surface) != VK_SUCCESS) {
            return VulkanError.CreateSurfaceFailed;
        }
    }

    fn pickPhysicalDevice(self: *Self) !void {
        var deviceCount: u32 = 0;
        if (c.vkEnumeratePhysicalDevices(self.instance, &deviceCount, null) != VK_SUCCESS) {
            return VulkanError.DeviceEnumerationFailed;
        }
        if (deviceCount == 0) {
            return VulkanError.NoValidDevices;
        }

        const devices = try self.allocator.alloc(c.VkPhysicalDevice, deviceCount);
        defer self.allocator.free(devices);
        if (c.vkEnumeratePhysicalDevices(self.instance, &deviceCount, devices.ptr) != VK_SUCCESS) {
            return VulkanError.DeviceEnumerationFailed;
        }

        var deviceSelected = false;
        var selectedDevice: c.VkPhysicalDevice = undefined;
        var selectedDeviceScore: u32 = 0;

        for (devices) |device| {
            var score = try calculateDeviceScore(self.allocator, device, self.surface);
            if (score > selectedDeviceScore and score > 1000) {
                deviceSelected = true;
                selectedDeviceScore = score;
                selectedDevice = device;
            }
        }

        if (!deviceSelected) {
            return VulkanError.NoValidDevices;
        } else {
            self.physical_device = selectedDevice;
        }
    }

    fn createLogicalDevice(self: *Self) !void {
        var queueCreateInfos = std.ArrayList(c.VkDeviceQueueCreateInfo).init(self.allocator);
        defer queueCreateInfos.deinit();

        const all_queue_families = [_]u32{ self.indices.graphics_family.?, self.indices.present_family.? };

        const uniqueQueueFamilies = if (self.indices.graphics_family.? == self.indices.present_family.?) all_queue_families[0..1] else all_queue_families[0..2];

        var queuePriority: f32 = 1.0;
        for (uniqueQueueFamilies) |queueFamily| {
            const queueCreateInfo = c.VkDeviceQueueCreateInfo{
                .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,

                .queueFamilyIndex = queueFamily,
                .queueCount = 1,
                .pQueuePriorities = &queuePriority,

                .pNext = null,
                .flags = 0,
            };
            try queueCreateInfos.append(queueCreateInfo);
        }

        const deviceFeatures = c.VkPhysicalDeviceFeatures{
            .robustBufferAccess = 0,
            .fullDrawIndexUint32 = 0,
            .imageCubeArray = 0,
            .independentBlend = 0,
            .geometryShader = 0,
            .tessellationShader = 0,
            .sampleRateShading = 0,
            .dualSrcBlend = 0,
            .logicOp = 0,
            .multiDrawIndirect = 0,
            .drawIndirectFirstInstance = 0,
            .depthClamp = 0,
            .depthBiasClamp = 0,
            .fillModeNonSolid = 0,
            .depthBounds = 0,
            .wideLines = 0,
            .largePoints = 0,
            .alphaToOne = 0,
            .multiViewport = 0,
            .samplerAnisotropy = 0,
            .textureCompressionETC2 = 0,
            .textureCompressionASTC_LDR = 0,
            .textureCompressionBC = 0,
            .occlusionQueryPrecise = 0,
            .pipelineStatisticsQuery = 0,
            .vertexPipelineStoresAndAtomics = 0,
            .fragmentStoresAndAtomics = 0,
            .shaderTessellationAndGeometryPointSize = 0,
            .shaderImageGatherExtended = 0,
            .shaderStorageImageExtendedFormats = 0,
            .shaderStorageImageMultisample = 0,
            .shaderStorageImageReadWithoutFormat = 0,
            .shaderStorageImageWriteWithoutFormat = 0,
            .shaderUniformBufferArrayDynamicIndexing = 0,
            .shaderSampledImageArrayDynamicIndexing = 0,
            .shaderStorageBufferArrayDynamicIndexing = 0,
            .shaderStorageImageArrayDynamicIndexing = 0,
            .shaderClipDistance = 0,
            .shaderCullDistance = 0,
            .shaderFloat64 = 0,
            .shaderInt64 = 0,
            .shaderInt16 = 0,
            .shaderResourceResidency = 0,
            .shaderResourceMinLod = 0,
            .sparseBinding = 0,
            .sparseResidencyBuffer = 0,
            .sparseResidencyImage2D = 0,
            .sparseResidencyImage3D = 0,
            .sparseResidency2Samples = 0,
            .sparseResidency4Samples = 0,
            .sparseResidency8Samples = 0,
            .sparseResidency16Samples = 0,
            .sparseResidencyAliased = 0,
            .variableMultisampleRate = 0,
            .inheritedQueries = 0,
        };

        const createInfo = c.VkDeviceCreateInfo{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,

            .queueCreateInfoCount = @intCast(u32, queueCreateInfos.items.len),
            .pQueueCreateInfos = queueCreateInfos.items.ptr,

            .pEnabledFeatures = &deviceFeatures,

            .enabledExtensionCount = @intCast(u32, deviceExtensions.len),
            .ppEnabledExtensionNames = &deviceExtensions,

            .enabledLayerCount = if (enableValidationLayers) @intCast(u32, validationLayers.len) else 0,
            .ppEnabledLayerNames = if (enableValidationLayers) &validationLayers else null,

            .pNext = null,
            .flags = 0,
        };

        if (c.vkCreateDevice(self.physical_device, &createInfo, null, &self.device) != VK_SUCCESS) {
            return VulkanError.CreateDeviceFailed;
        }

        c.vkGetDeviceQueue(self.device, self.indices.graphics_family.?, 0, &self.graphics_queue);
        c.vkGetDeviceQueue(self.device, self.indices.present_family.?, 0, &self.present_queue);
    }
};

fn calculateDeviceScore(allocator: *Allocator, device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) !u32 {
    var deviceProperties: c.VkPhysicalDeviceProperties = undefined;
    var deviceMemProperties: c.VkPhysicalDeviceMemoryProperties = undefined;
    var deviceFeatures: c.VkPhysicalDeviceFeatures = undefined;
    c.vkGetPhysicalDeviceProperties(device, &deviceProperties);
    c.vkGetPhysicalDeviceMemoryProperties(device, &deviceMemProperties);
    c.vkGetPhysicalDeviceFeatures(device, &deviceFeatures);

    var score: u32 = 0;

    if (deviceProperties.deviceType == c.enum_VkPhysicalDeviceType.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) {
        score += 4200;
    }

    score += @intCast(u32, deviceProperties.limits.maxImageDimension2D);

    score += @intCast(u32, deviceMemProperties.memoryHeapCount);

    //----- Must Haves
    if (deviceFeatures.geometryShader == 0) {
        return 0;
    }

    const indices = try findQueueFamilies(allocator, device, surface);
    if (!indices.isComplete()) {
        return 0;
    }

    const extensionsSupported = try checkDeviceExtensionSupport(allocator, device);
    if (!extensionsSupported) {
        return 0;
    }

    const swapchainSupport = try swapchain.querySwapchainSupport(allocator, device, surface);
    defer swapchainSupport.deinit();
    if (swapchainSupport.formats.items.len == 0 and swapchainSupport.present_modes.items.len == 0) {
        return 0;
    }

    return score;
}

fn checkDeviceExtensionSupport(allocator: *Allocator, device: c.VkPhysicalDevice) !bool {
    var extensionCount: u32 = 0;
    if (c.vkEnumerateDeviceExtensionProperties(device, null, &extensionCount, null) != VK_SUCCESS) {
        return VulkanError.ExtensionEnumerationFailed;
    }

    const availableExtensions = try allocator.alloc(c.VkExtensionProperties, extensionCount);
    defer allocator.free(availableExtensions);
    if (c.vkEnumerateDeviceExtensionProperties(device, null, &extensionCount, availableExtensions.ptr) != VK_SUCCESS) {
        return VulkanError.ExtensionEnumerationFailed;
    }

    for (deviceExtensions) |deviceExt| {
        var extensionFound = false;

        for (availableExtensions) |extension| {
            if (std.cstr.cmp(deviceExt, @ptrCast([*c]const u8, &extension.extensionName)) == 0) {
                extensionFound = true;
                break;
            }
        }

        if (!extensionFound) {
            return false;
        }
    }

    return true;
}

fn findQueueFamilies(allocator: *Allocator, device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) !QueueFamilyIndices {
    var indices = QueueFamilyIndices.init();

    var queueFamilyCount: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, null);

    const queueFamilies = try allocator.alloc(c.VkQueueFamilyProperties, queueFamilyCount);
    defer allocator.free(queueFamilies);
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queueFamilies.ptr);

    var i: u32 = 0;
    for (queueFamilies) |queueFamily| {
        if (queueFamily.queueCount < 0) {
            continue;
        }

        if (queueFamily.queueFlags & @intCast(u32, c.VK_QUEUE_GRAPHICS_BIT) != 0) {
            indices.graphics_family = i;
        }

        var presentSupport: u32 = 0;
        if (c.vkGetPhysicalDeviceSurfaceSupportKHR(device, i, surface, &presentSupport) != VK_SUCCESS) {
            return error.Unexpected;
        }
        indices.present_family = i;

        if (indices.isComplete()) {
            break;
        }

        i += 1;
    }

    return indices;
}