const std = @import("std");

const Allocator = std.mem.Allocator;

const vk = @import("../include/vk.zig");
const VK_SUCCESS = vk.Result.SUCCESS;

const glfw = @import("../include/glfw.zig");

const windowing = @import("../windowing.zig");

const shader = @import("shader.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const Gpu = @import("gpu.zig").Gpu;
const RenderPass = @import("renderpass.zig").RenderPass;
const GraphicsPipeline = @import("pipeline.zig").GraphicsPipeline;
const Command = @import("command.zig").Command;

pub const Swapchain = struct {
    const Self = @This();
    allocator: *Allocator,

    swapchain: vk.SwapchainKHR,

    gpu: *Gpu,
    window: *windowing.Window,

    images: []vk.Image,
    imageviews: []vk.ImageView,
    image_format: vk.Format,
    extent: vk.Extent2D,

    current_image_id: u32,

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

            .current_image_id = 0,
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, gpu: *Gpu, window: *windowing.Window) !void {
        self.allocator = allocator;

        self.gpu = gpu;
        self.window = window;

        try self.createSwapchain();
        try self.createImageViews();
    }

    pub fn deinit(self: Self) void {
        for (self.imageviews) |imageView| {
            vk.DestroyImageView(self.gpu.device, imageView, null);
        }
        self.allocator.free(self.imageviews);

        self.allocator.free(self.images);

        vk.DestroySwapchainKHR(self.gpu.device, self.swapchain, null);
    }

    pub fn acquireNextImage(self: *Self, semaphore: vk.Semaphore, imageIndex: *u32) !bool {
        // self.current_image_id = imageIndex.*;
        var result = vk.vkAcquireNextImageKHR(self.gpu.device, self.swapchain, std.math.maxInt(u64), semaphore, .Null, imageIndex);
        if (result == .ERROR_OUT_OF_DATE_KHR) {
            return true;
        } else if (result != VK_SUCCESS and result != .SUBOPTIMAL_KHR) {
            return VulkanError.AcquireImageFailed;
        } else {
            return false;
        }
    }

    pub fn present(self: *Self, semaphore: vk.Semaphore, imageIndex: u32) !bool {
        const signalSemaphores = [_]vk.Semaphore{semaphore};
        const swapchains = [_]vk.SwapchainKHR{self.swapchain};
        const presentInfo = vk.PresentInfoKHR{
            .waitSemaphoreCount = signalSemaphores.len,
            .pWaitSemaphores = &signalSemaphores,

            .swapchainCount = swapchains.len,
            .pSwapchains = &swapchains,

            .pImageIndices = &[_]u32{imageIndex},
        };

        var result = vk.vkQueuePresentKHR(self.gpu.present_queue, &presentInfo);
        if (result == .ERROR_OUT_OF_DATE_KHR) {
            return true;
        } else if (result != VK_SUCCESS and result != .SUBOPTIMAL_KHR) {
            return VulkanError.PresentFailed;
        } else {
            return false;
        }
    }

    fn createSwapchain(self: *Self) !void {
        const swapchainSupport = try querySwapchainSupport(self.allocator, self.gpu.physical_device, self.gpu.surface);

        const surfaceFormat = chooseSwapchainSurfaceFormat(swapchainSupport.formats.items);
        const presentMode = chooseSwapchainPresentMode(swapchainSupport.present_modes.items);
        const extent = chooseSwapchainExtent(swapchainSupport.capabilities, self.window.window);

        var imageCount: u32 = swapchainSupport.capabilities.minImageCount + 1;
        if (swapchainSupport.capabilities.maxImageCount > 0) {
            imageCount = std.math.min(imageCount, swapchainSupport.capabilities.maxImageCount);
        }

        const indices = self.gpu.indices;
        const queueFamilyIndices = [_]u32{ indices.graphics_family.?, indices.present_family.? };
        const differentFamilies = indices.graphics_family.? != indices.present_family.?;

        var createInfo = vk.SwapchainCreateInfoKHR{
            .surface = self.gpu.surface,

            .minImageCount = imageCount,
            .imageFormat = surfaceFormat.format,
            .imageColorSpace = surfaceFormat.colorSpace,
            .imageExtent = extent,
            .imageArrayLayers = 1,
            .imageUsage = vk.ImageUsageFlags{ .colorAttachment = true },

            .imageSharingMode = if (differentFamilies) .CONCURRENT else .EXCLUSIVE,
            .queueFamilyIndexCount = if (differentFamilies) 2 else 0,
            .pQueueFamilyIndices = if (differentFamilies) &queueFamilyIndices else undefined,

            .preTransform = swapchainSupport.capabilities.currentTransform,
            .compositeAlpha = vk.CompositeAlphaFlagsKHR{ .opaque = true },

            .presentMode = presentMode,
            .clipped = vk.TRUE,
        };

        self.swapchain = try vk.CreateSwapchainKHR(self.gpu.device, createInfo, null);

        imageCount = try vk.GetSwapchainImagesCountKHR(self.gpu.device, self.swapchain);
        self.images = try self.allocator.alloc(vk.Image, imageCount);
        _ = try vk.GetSwapchainImagesKHR(self.gpu.device, self.swapchain, self.images);

        self.image_format = surfaceFormat.format;
        self.extent = extent;
    }

    fn createImageViews(self: *Self) !void {
        self.imageviews = try self.allocator.alloc(vk.ImageView, self.images.len);
        errdefer self.allocator.free(self.imageviews);

        for (self.images) |image, i| {
            const createInfo = vk.ImageViewCreateInfo{
                .image = image,
                .viewType = .T_2D,
                .format = self.image_format,
                .components = vk.ComponentMapping{
                    .r = .IDENTITY,
                    .g = .IDENTITY,
                    .b = .IDENTITY,
                    .a = .IDENTITY,
                },

                .subresourceRange = vk.ImageSubresourceRange{
                    .aspectMask = vk.ImageAspectFlags{ .color = true },
                    .baseMipLevel = 0,
                    .levelCount = 1,
                    .baseArrayLayer = 0,
                    .layerCount = 1,
                },
            };

            self.imageviews[i] = try vk.CreateImageView(self.gpu.device, createInfo, null);
        }
    }
};

const SwapchainSupportDetails = struct {
    const Self = @This();

    capabilities: vk.SurfaceCapabilitiesKHR,
    formats: std.ArrayList(vk.SurfaceFormatKHR),
    present_modes: std.ArrayList(vk.PresentModeKHR),

    fn init(allocator: *Allocator) Self {
        return Self{
            .capabilities = undefined,
            .formats = std.ArrayList(vk.SurfaceFormatKHR).init(allocator),
            .present_modes = std.ArrayList(vk.PresentModeKHR).init(allocator),
        };
    }

    pub fn deinit(self: Self) void {
        self.formats.deinit();
        self.present_modes.deinit();
    }
};

pub fn querySwapchainSupport(allocator: *Allocator, device: vk.PhysicalDevice, surface: vk.SurfaceKHR) !SwapchainSupportDetails {
    var details = SwapchainSupportDetails.init(allocator);

    details.capabilities = try vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface);

    var formatCount = try vk.GetPhysicalDeviceSurfaceFormatsCountKHR(device, surface);
    if (formatCount != 0) {
        try details.formats.resize(formatCount);
        _ = try vk.GetPhysicalDeviceSurfaceFormatsKHR(device, surface, details.formats.items);
    }

    var presentModeCount = try vk.GetPhysicalDeviceSurfacePresentModesCountKHR(device, surface);
    if (presentModeCount != 0) {
        try details.present_modes.resize(presentModeCount);
        _ = try vk.GetPhysicalDeviceSurfacePresentModesKHR(device, surface, details.present_modes.items);
    }

    return details;
}

pub fn chooseSwapchainSurfaceFormat(availableFormats: []vk.SurfaceFormatKHR) vk.SurfaceFormatKHR {
    if (availableFormats.len == 1 and availableFormats[0].format == .UNDEFINED) {
        return vk.SurfaceFormatKHR{
            .format = .B8G8R8A8_UNORM,
            .colorSpace = .SRGB_NONLINEAR,
        };
    }

    for (availableFormats) |format| {
        if (format.format == .B8G8R8A8_UNORM and
            format.colorSpace == .SRGB_NONLINEAR)
        {
            return format;
        }
    }

    return availableFormats[0];
}

pub fn chooseSwapchainPresentMode(availablePresentModes: []vk.PresentModeKHR) vk.PresentModeKHR {
    for (availablePresentModes) |presentMode| {
        if (presentMode == .MAILBOX) {
            return presentMode;
        }
    }

    return .FIFO;
}

pub fn chooseSwapchainExtent(capabilities: vk.SurfaceCapabilitiesKHR, window: *glfw.GLFWwindow) vk.Extent2D {
    if (capabilities.currentExtent.width != std.math.maxInt(u32)) {
        return vk.Extent2D{ .width = capabilities.currentExtent.width, .height = capabilities.currentExtent.height };
    } else {
        var width: c_int = 0;
        var height: c_int = 0;
        glfw.glfwGetFramebufferSize(window, &width, &height);

        var actualExtent = vk.Extent2D{
            .width = @intCast(u32, width),
            .height = @intCast(u32, height),
        };

        actualExtent.width = @intCast(u32, std.math.max(capabilities.minImageExtent.width, std.math.min(capabilities.maxImageExtent.width, actualExtent.width)));
        actualExtent.height = @intCast(u32, std.math.max(capabilities.minImageExtent.height, std.math.min(capabilities.maxImageExtent.height, actualExtent.height)));

        return actualExtent;
    }
}
