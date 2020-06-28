const std = @import("std");

const Allocator = std.mem.Allocator;

const vk = @import("../include/vk.zig");
const VK_SUCCESS = vk.Result.SUCCESS;

const glfw = @import("../include/glfw.zig");

const windowing = @import("../windowing.zig");

const shader = @import("shader.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const swapchain = @import("swapchain.zig");

const enableValidationLayers = std.debug.runtime_safety;
const validationLayers = [_][*:0]const u8{"VK_LAYER_LUNARG_standard_validation"};
const deviceExtensions = [_][*:0]const u8{vk.KHR_SWAPCHAIN_EXTENSION_NAME};

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

pub const Gpu = struct {
    const Self = @This();
    allocator: *Allocator,

    instance: vk.Instance,
    window: *windowing.Window,

    indices: QueueFamilyIndices,

    physical_device: vk.PhysicalDevice,
    properties: vk.PhysicalDeviceProperties,
    mem_properties: vk.PhysicalDeviceMemoryProperties,
    features: vk.PhysicalDeviceFeatures,

    device: vk.Device,
    surface: vk.SurfaceKHR,

    graphics_queue: vk.Queue,
    present_queue: vk.Queue,
    transfer_queue: vk.Queue,

    graphics_pool: vk.CommandPool,
    transfer_pool: vk.CommandPool,

    pub fn new(instance: vk.Instance, window: *windowing.Window) Self {
        return Self{
            .allocator = undefined,

            .instance = instance,
            .window = window,

            .indices = undefined,

            .physical_device = undefined,
            .properties = undefined,
            .mem_properties = undefined,
            .features = undefined,

            .device = undefined,
            .surface = undefined,

            .graphics_queue = undefined,
            .present_queue = undefined,
            .transfer_queue = undefined,

            .graphics_pool = undefined,
            .transfer_pool = undefined,
        };
    }

    pub fn init(self: *Self, allocator: *Allocator) !void {
        self.allocator = allocator;

        try self.createSurface();
        try self.pickPhysicalDevice();

        self.indices = try findQueueFamilies(self.allocator, self.physical_device, self.surface);

        try self.createLogicalDevice();

        try self.createGraphicsPool();
        try self.createTransferPool();
    }

    pub fn deinit(self: Self) void {
        vk.DestroyCommandPool(self.device, self.graphics_pool, null);
        vk.DestroyCommandPool(self.device, self.transfer_pool, null);

        vk.DestroyDevice(self.device, null);

        vk.DestroySurfaceKHR(self.instance, self.surface, null);
    }

    fn createSurface(self: *Self) !void {
        if (glfw.glfwCreateWindowSurface(self.instance, self.window.window, null, &self.surface) != VK_SUCCESS) {
            return VulkanError.CreateSurfaceFailed;
        }
    }

    fn pickPhysicalDevice(self: *Self) !void {
        var deviceCount: u32 = 0;
        if (vk.vkEnumeratePhysicalDevices(self.instance, &deviceCount, null) != VK_SUCCESS) {
            return VulkanError.DeviceEnumerationFailed;
        }
        if (deviceCount == 0) {
            return VulkanError.NoValidDevices;
        }

        const devices = try self.allocator.alloc(vk.PhysicalDevice, deviceCount);
        defer self.allocator.free(devices);
        _ = try vk.EnumeratePhysicalDevices(self.instance, devices);

        var deviceSelected = false;
        var selectedDevice: vk.PhysicalDevice = undefined;
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

        self.properties = vk.GetPhysicalDeviceProperties(self.physical_device);
        self.mem_properties = vk.GetPhysicalDeviceMemoryProperties(self.physical_device);
        self.features = vk.GetPhysicalDeviceFeatures(self.physical_device);
    }

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
                .queueFamilyIndex = queueFamily,
                .queueCount = 1,
                .pQueuePriorities = &[_]f32{queuePriority},
            };
            try queueCreateInfos.append(queueCreateInfo);
        }

        const deviceFeatures = vk.PhysicalDeviceFeatures{
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

        const createInfo = vk.DeviceCreateInfo{
            .queueCreateInfoCount = @intCast(u32, queueCreateInfos.items.len),
            .pQueueCreateInfos = queueCreateInfos.items.ptr,

            .pEnabledFeatures = &deviceFeatures,

            .enabledExtensionCount = @intCast(u32, deviceExtensions.len),
            .ppEnabledExtensionNames = &deviceExtensions,

            .enabledLayerCount = if (enableValidationLayers) @intCast(u32, validationLayers.len) else 0,
            .ppEnabledLayerNames = if (enableValidationLayers) &validationLayers else undefined,
        };

        self.device = try vk.CreateDevice(self.physical_device, createInfo, null);

        self.graphics_queue = vk.GetDeviceQueue(self.device, self.indices.graphics_family.?, 0);
        self.present_queue = vk.GetDeviceQueue(self.device, self.indices.present_family.?, 0);
        self.transfer_queue = vk.GetDeviceQueue(self.device, self.indices.transfer_family.?, 0);
    }

    fn createGraphicsPool(self: *Self) !void {
        const indices = self.indices;

        const poolInfo = vk.CommandPoolCreateInfo{
            .queueFamilyIndex = indices.graphics_family.?,
        };

        self.graphics_pool = try vk.CreateCommandPool(self.device, poolInfo, null);
    }

    fn createTransferPool(self: *Self) !void {
        const indices = self.indices;

        const poolInfo = vk.CommandPoolCreateInfo{
            .queueFamilyIndex = indices.transfer_family.?,
        };

        self.transfer_pool = try vk.CreateCommandPool(self.device, poolInfo, null);
    }
};

fn calculateDeviceScore(allocator: *Allocator, device: vk.PhysicalDevice, surface: vk.SurfaceKHR) !u32 {
    var deviceProperties: vk.PhysicalDeviceProperties = vk.GetPhysicalDeviceProperties(device);
    var deviceMemProperties: vk.PhysicalDeviceMemoryProperties = vk.GetPhysicalDeviceMemoryProperties(device);
    var deviceFeatures: vk.PhysicalDeviceFeatures = vk.GetPhysicalDeviceFeatures(device);

    var score: u32 = 0;

    if (deviceProperties.deviceType == .DISCRETE_GPU) {
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

fn checkDeviceExtensionSupport(allocator: *Allocator, device: vk.PhysicalDevice) !bool {
    var extensionCount = try vk.EnumerateDeviceExtensionPropertiesCount(device, null);

    const availableExtensions = try allocator.alloc(vk.ExtensionProperties, extensionCount);
    defer allocator.free(availableExtensions);
    _ = try vk.EnumerateDeviceExtensionProperties(device, null, availableExtensions);

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

fn findQueueFamilies(allocator: *Allocator, device: vk.PhysicalDevice, surface: vk.SurfaceKHR) !QueueFamilyIndices {
    var indices = QueueFamilyIndices.init();

    var queueFamilyCount = vk.GetPhysicalDeviceQueueFamilyPropertiesCount(device);

    const queueFamilies = try allocator.alloc(vk.QueueFamilyProperties, queueFamilyCount);
    defer allocator.free(queueFamilies);
    _ = vk.GetPhysicalDeviceQueueFamilyProperties(device, queueFamilies);

    var i: u32 = 0;
    for (queueFamilies) |queueFamily| {
        if (queueFamily.queueCount < 0) {
            continue;
        }

        if (queueFamily.queueFlags.graphics) {
            indices.graphics_family = i;
        }
        if (queueFamily.queueFlags.transfer) {
            indices.transfer_family = i;
        }

        if ((try vk.GetPhysicalDeviceSurfaceSupportKHR(device, i, surface)) != 0) {
            indices.present_family = i;
        }

        if (indices.isComplete()) {
            break;
        }

        i += 1;
    }

    return indices;
}
