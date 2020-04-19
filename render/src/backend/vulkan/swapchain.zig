const std = @import("std");

const Allocator = std.mem.Allocator;

const c = @import("../../c2.zig");
const VK_SUCCESS = c.enum_VkResult.VK_SUCCESS;

const windowing = @import("../../windowing.zig");

const backend = @import("../backend.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const Gpu = @import("gpu.zig").Gpu;
const RenderPass = @import("renderpass.zig").RenderPass;
const GraphicsPipeline = @import("pipeline.zig").GraphicsPipeline;
const Command = @import("command.zig").Command;

pub const Swapchain = struct {
    const Self = @This();
    allocator: *Allocator,

    swapchain: c.VkSwapchainKHR,

    gpu: Gpu,
    window: *windowing.Window,

    images: []c.VkImage,
    imageviews: []c.VkImageView,
    image_format: c.VkFormat,
    extent: c.VkExtent2D,

    framebuffers: []c.VkFramebuffer,

    pub fn new() Self {
        return Self{
            .allocator = undefined,

            .swapchain = undefined,

            .gpu = undefined,
            .window = undefined,

            .images = undefined,
            .imageviews = undefined,
            .image_format = undefined,
            .extent = undefined,

            .framebuffers = undefined,
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, gpu: Gpu, window: *windowing.Window) !void {
        self.allocator = allocator;

        self.gpu = gpu;
        self.window = window;

        try self.createSwapchain();
        try self.createImageViews();
    }

    pub fn deinit(self: Self) void {
        for (self.imageviews) |imageView| {
            c.vkDestroyImageView(self.gpu.device, imageView, null);
        }
        self.allocator.free(self.imageviews);

        self.allocator.free(self.images);

        c.vkDestroySwapchainKHR(self.gpu.device, self.swapchain, null);
    }

    fn createSwapchain(self: *Self) !void {
        const swapchainSupport = try querySwapchainSupport(self.allocator, self.gpu.physical_device, self.gpu.surface);

        const surfaceFormat = chooseSwapchainSurfaceFormat(swapchainSupport.formats.items);
        const presentMode = chooseSwapchainPresentMode(swapchainSupport.present_modes.items);
        const extent = chooseSwapchainExtent(swapchainSupport.capabilities, self.window.window);

        var imageCount = swapchainSupport.capabilities.minImageCount + 1;
        if (swapchainSupport.capabilities.maxImageCount > 0) {
            imageCount = std.math.min(imageCount, swapchainSupport.capabilities.maxImageCount);
        }

        const indices = self.gpu.indices;
        const queueFamilyIndices = [_]u32{ indices.graphics_family.?, indices.present_family.? };
        const differentFamilies = indices.graphics_family.? != indices.present_family.?;

        var createInfo = c.VkSwapchainCreateInfoKHR{
            .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,

            .surface = self.gpu.surface,

            .minImageCount = imageCount,
            .imageFormat = surfaceFormat.format,
            .imageColorSpace = surfaceFormat.colorSpace,
            .imageExtent = extent,
            .imageArrayLayers = 1,
            .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,

            .imageSharingMode = if (differentFamilies) c.enum_VkSharingMode.VK_SHARING_MODE_CONCURRENT else c.enum_VkSharingMode.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = if (differentFamilies) 2 else 0,
            .pQueueFamilyIndices = if (differentFamilies) &queueFamilyIndices else null,

            .preTransform = swapchainSupport.capabilities.currentTransform,
            .compositeAlpha = c.enum_VkCompositeAlphaFlagBitsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,

            .presentMode = presentMode,
            .clipped = c.VK_TRUE,

            .oldSwapchain = null,

            .pNext = null,
            .flags = 0,
        };

        if (c.vkCreateSwapchainKHR(self.gpu.device, &createInfo, null, &self.swapchain) != VK_SUCCESS) {
            return VulkanError.CreateSwapchainFailed;
        }

        if (c.vkGetSwapchainImagesKHR(self.gpu.device, self.swapchain, &imageCount, null) != VK_SUCCESS) {
            return VulkanError.GetImagesFailed;
        }
        self.images = try self.allocator.alloc(c.VkImage, imageCount);
        if (c.vkGetSwapchainImagesKHR(self.gpu.device, self.swapchain, &imageCount, self.images.ptr) != VK_SUCCESS) {
            return VulkanError.GetImagesFailed;
        }

        self.image_format = surfaceFormat.format;
        self.extent = extent;
    }

    fn createImageViews(self: *Self) !void {
        self.imageviews = try self.allocator.alloc(c.VkImageView, self.images.len);
        errdefer self.allocator.free(self.imageviews);

        for (self.images) |image, i| {
            const createInfo = c.VkImageViewCreateInfo{
                .sType = c.enum_VkStructureType.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,

                .image = image,
                .viewType = c.enum_VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
                .format = self.image_format,
                .components = c.VkComponentMapping{
                    .r = c.enum_VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .g = c.enum_VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .b = c.enum_VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .a = c.enum_VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                },

                .subresourceRange = c.VkImageSubresourceRange{
                    .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                    .baseMipLevel = 0,
                    .levelCount = 1,
                    .baseArrayLayer = 0,
                    .layerCount = 1,
                },

                .pNext = null,
                .flags = 0,
            };

            if (c.vkCreateImageView(self.gpu.device, &createInfo, null, &self.imageviews[i]) != VK_SUCCESS) {
                return VulkanError.CreateImageViewFailed;
            }
        }
    }
};

const SwapchainSupportDetails = struct {
    const Self = @This();

    capabilities: c.VkSurfaceCapabilitiesKHR,
    formats: std.ArrayList(c.VkSurfaceFormatKHR),
    present_modes: std.ArrayList(c.VkPresentModeKHR),

    fn init(allocator: *Allocator) Self {
        return Self{
            .capabilities = undefined,
            .formats = std.ArrayList(c.VkSurfaceFormatKHR).init(allocator),
            .present_modes = std.ArrayList(c.VkPresentModeKHR).init(allocator),
        };
    }

    fn deinit(self: Self) void {
        self.formats.deinit();
        self.present_modes.deinit();
    }
};

pub fn querySwapchainSupport(allocator: *Allocator, device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) !SwapchainSupportDetails {
    var details = SwapchainSupportDetails.init(allocator);

    if (c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &details.capabilities) != VK_SUCCESS) {
        return VulkanError.QuerySwapchainSupportFailed;
    }

    var formatCount: u32 = 0;
    if (c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &formatCount, null) != VK_SUCCESS) {
        return VulkanError.QuerySwapchainSupportFailed;
    }

    if (formatCount != 0) {
        try details.formats.resize(formatCount);
        if (c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &formatCount, details.formats.items.ptr) != VK_SUCCESS) {
            return VulkanError.QuerySwapchainSupportFailed;
        }
    }

    var presentModeCount: u32 = 0;
    if (c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &presentModeCount, null) != VK_SUCCESS) {
        return VulkanError.QuerySwapchainSupportFailed;
    }

    if (presentModeCount != 0) {
        try details.present_modes.resize(presentModeCount);
        if (c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &presentModeCount, details.present_modes.items.ptr) != VK_SUCCESS) {
            return VulkanError.QuerySwapchainSupportFailed;
        }
    }

    return details;
}

pub fn chooseSwapchainSurfaceFormat(availableFormats: []c.VkSurfaceFormatKHR) c.VkSurfaceFormatKHR {
    if (availableFormats.len == 1 and availableFormats[0].format == c.enum_VkFormat.VK_FORMAT_UNDEFINED) {
        return c.VkSurfaceFormatKHR{
            .format = c.enum_VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
            .colorSpace = c.enum_VkColorSpaceKHR.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
        };
    }

    for (availableFormats) |format| {
        if (format.format == c.enum_VkFormat.VK_FORMAT_B8G8R8A8_UNORM and
            format.colorSpace == c.enum_VkColorSpaceKHR.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
        {
            return format;
        }
    }

    return availableFormats[0];
}

pub fn chooseSwapchainPresentMode(availablePresentModes: []c.VkPresentModeKHR) c.VkPresentModeKHR {
    for (availablePresentModes) |presentMode| {
        if (presentMode == c.enum_VkPresentModeKHR.VK_PRESENT_MODE_MAILBOX_KHR) {
            return presentMode;
        }
    }

    return c.enum_VkPresentModeKHR.VK_PRESENT_MODE_FIFO_KHR;
}

pub fn chooseSwapchainExtent(capabilities: c.VkSurfaceCapabilitiesKHR, window: *c.GLFWwindow) c.VkExtent2D {
    if (capabilities.currentExtent.width != std.math.maxInt(u32)) {
        return c.VkExtent2D{ .width = capabilities.currentExtent.width, .height = capabilities.currentExtent.height };
    } else {
        var width: c_int = 0;
        var height: c_int = 0;
        c.glfwGetFramebufferSize(window, &width, &height);

        var actualExtent = c.VkExtent2D{
            .width = @intCast(u32, width),
            .height = @intCast(u32, height),
        };

        actualExtent.width = @intCast(u32, std.math.max(capabilities.minImageExtent.width, std.math.min(capabilities.maxImageExtent.width, actualExtent.width)));
        actualExtent.height = @intCast(u32, std.math.max(capabilities.minImageExtent.height, std.math.min(capabilities.maxImageExtent.height, actualExtent.height)));

        return actualExtent;
    }
}
