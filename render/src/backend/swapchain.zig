const std = @import("std");

const Allocator = std.mem.Allocator;

const vk = @import("../include/vk.zig");

const glfw = @import("../include/glfw.zig");

const windowing = @import("../windowing.zig");

const shader = @import("shader.zig");

const vkbackend = @import("backend.zig");
const VulkanError = vkbackend.VulkanError;

const Context = @import("context.zig").Context;
const RenderPass = @import("renderpass.zig").RenderPass;
const GraphicsPipeline = @import("pipeline.zig").GraphicsPipeline;
const Command = @import("command.zig").Command;

pub const Swapchain = struct {
    const Self = @This();
    allocator: *Allocator,

    swapchain: vk.SwapchainKHR,

    context: *Context,
    window: *windowing.Window,

    swapchain_support: SwapchainSupportDetails,
    images: []vk.Image,
    imageviews: []vk.ImageView,
    image_format: vk.Format,
    extent: vk.Extent2D,

    current_image_id: u32,

    pub fn new() Self {
        return Self{
            .allocator = undefined,

            .swapchain = undefined,

            .context = undefined,
            .window = undefined,

            .swapchain_support = undefined,
            .images = undefined,
            .imageviews = undefined,
            .image_format = undefined,
            .extent = undefined,

            .current_image_id = 0,
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, context: *Context, window: *windowing.Window) !void {
        self.allocator = allocator;

        self.context = context;
        self.window = window;

        try self.createSwapchain();
        try self.createImageViews();
    }

    pub fn deinit(self: Self) void {
        for (self.imageviews) |imageView| {
            self.context.vkd.destroyImageView(self.context.device, imageView, null);
        }
        self.allocator.free(self.imageviews);

        self.allocator.free(self.images);

        self.context.vkd.destroySwapchainKHR(self.context.device, self.swapchain, null);

        self.swapchain_support.deinit();
    }

    pub fn acquireNextImage(self: *Self, semaphore: vk.Semaphore, imageIndex: *u32) !bool {
        var result = try self.context.vkd.acquireNextImageKHR(self.context.device, self.swapchain, std.math.maxInt(u64), semaphore, .null_handle);
        imageIndex.* = result.image_index;
        if (result.result == .error_out_of_date_khr) {
            return true;
        } else if (result.result != vk.Result.success and result.result != .suboptimal_khr) {
            return VulkanError.AcquireImageFailed;
        } else {
            return false;
        }
    }

    pub fn present(self: *Self, semaphore: vk.Semaphore, imageIndex: u32) !bool {
        const presentInfo = vk.PresentInfoKHR{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast([*]const vk.Semaphore, &semaphore),

            .swapchain_count = 1,
            .p_swapchains = @ptrCast([*]const vk.SwapchainKHR, &self.swapchain),

            .p_image_indices = @ptrCast([*]const u32, &imageIndex),

            .p_results = null,
        };

        var result = try self.context.vkd.queuePresentKHR(self.context.present_queue, presentInfo);
        if (result == .error_out_of_date_khr) {
            return true;
        } else if (result != vk.Result.success and result != .suboptimal_khr) {
            return VulkanError.PresentFailed;
        } else {
            return false;
        }
    }

    fn createSwapchain(self: *Self) !void {
        self.swapchain_support = try querySwapchainSupport(self.allocator, self.context, self.context.physical_device, self.context.surface);

        const surfaceFormat = chooseSwapchainSurfaceFormat(self.swapchain_support.formats.items);
        const presentMode = chooseSwapchainPresentMode(self.swapchain_support.present_modes.items);
        const extent = chooseSwapchainExtent(self.swapchain_support.capabilities, self.window.window);

        var imageCount: u32 = self.swapchain_support.capabilities.min_image_count + 1;
        if (self.swapchain_support.capabilities.max_image_count > 0) {
            imageCount = std.math.min(imageCount, self.swapchain_support.capabilities.max_image_count);
        }

        const indices = self.context.indices;
        const queueFamilyIndices = [_]u32{ indices.graphics_family.?, indices.present_family.? };
        const differentFamilies = indices.graphics_family.? != indices.present_family.?;

        var createInfo = vk.SwapchainCreateInfoKHR{
            .surface = self.context.surface,

            .min_image_count = imageCount,
            .image_format = surfaceFormat.format,
            .image_color_space = surfaceFormat.color_space,
            .image_extent = extent,
            .image_array_layers = 1,
            .image_usage = vk.ImageUsageFlags{ .color_attachment_bit = true },

            .image_sharing_mode = if (differentFamilies) .concurrent else .exclusive,
            .queue_family_index_count = if (differentFamilies) 2 else 0,
            .p_queue_family_indices = if (differentFamilies) &queueFamilyIndices else undefined,

            .pre_transform = self.swapchain_support.capabilities.current_transform,
            .composite_alpha = vk.CompositeAlphaFlagsKHR{ .opaque_bit_khr = true },

            .present_mode = presentMode,
            .clipped = vk.TRUE,

            .flags = .{},
            .old_swapchain = .null_handle,
        };

        self.swapchain = try self.context.vkd.createSwapchainKHR(self.context.device, createInfo, null);

        _ = try self.context.vkd.getSwapchainImagesKHR(self.context.device, self.swapchain, &imageCount, null);
        self.images = try self.allocator.alloc(vk.Image, imageCount);
        _ = try self.context.vkd.getSwapchainImagesKHR(self.context.device, self.swapchain, &imageCount, self.images.ptr);

        self.image_format = surfaceFormat.format;
        self.extent = extent;
    }

    fn createImageViews(self: *Self) !void {
        self.imageviews = try self.allocator.alloc(vk.ImageView, self.images.len);
        errdefer self.allocator.free(self.imageviews);

        for (self.images) |image, i| {
            const createInfo = vk.ImageViewCreateInfo{
                .image = image,
                .view_type = .@"2d",
                .format = self.image_format,
                .components = vk.ComponentMapping{
                    .r = .identity,
                    .g = .identity,
                    .b = .identity,
                    .a = .identity,
                },

                .subresource_range = vk.ImageSubresourceRange{
                    .aspect_mask = vk.ImageAspectFlags{ .color_bit = true },
                    .base_mip_level = 0,
                    .level_count = 1,
                    .base_array_layer = 0,
                    .layer_count = 1,
                },

                .flags = .{},
            };

            self.imageviews[i] = try self.context.vkd.createImageView(self.context.device, createInfo, null);
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

pub fn querySwapchainSupport(allocator: *Allocator, context: *Context, pdevice: vk.PhysicalDevice, surface: vk.SurfaceKHR) !SwapchainSupportDetails {
    var details = SwapchainSupportDetails.init(allocator);

    details.capabilities = try context.vki.getPhysicalDeviceSurfaceCapabilitiesKHR(pdevice, surface);

    var formatCount: u32 = 0;
    _ = try context.vki.getPhysicalDeviceSurfaceFormatsKHR(pdevice, surface, &formatCount, null);
    if (formatCount != 0) {
        try details.formats.resize(formatCount);
        _ = try context.vki.getPhysicalDeviceSurfaceFormatsKHR(pdevice, surface, &formatCount, details.formats.items.ptr);
    }

    var presentModeCount: u32 = 0;
    _ = try context.vki.getPhysicalDeviceSurfacePresentModesKHR(pdevice, surface, &presentModeCount, null);
    if (presentModeCount != 0) {
        try details.present_modes.resize(presentModeCount);
        _ = try context.vki.getPhysicalDeviceSurfacePresentModesKHR(pdevice, surface, &presentModeCount, details.present_modes.items.ptr);
    }

    return details;
}

pub fn chooseSwapchainSurfaceFormat(availableFormats: []vk.SurfaceFormatKHR) vk.SurfaceFormatKHR {
    if (availableFormats.len == 1 and availableFormats[0].format == .@"undefined") {
        return vk.SurfaceFormatKHR{
            .format = .b8g8r8_unorm,
            .color_space = .srgb_nonlinear_khr,
        };
    }

    for (availableFormats) |format| {
        if (format.format == .b8g8r8_unorm and
            format.color_space == .srgb_nonlinear_khr)
        {
            return format;
        }
    }

    return availableFormats[0];
}

pub fn chooseSwapchainPresentMode(availablePresentModes: []vk.PresentModeKHR) vk.PresentModeKHR {
    for (availablePresentModes) |presentMode| {
        if (presentMode == .mailbox_khr) {
            return presentMode;
        }
    }

    return .fifo_khr;
}

pub fn chooseSwapchainExtent(capabilities: vk.SurfaceCapabilitiesKHR, window: *glfw.GLFWwindow) vk.Extent2D {
    if (capabilities.current_extent.width != std.math.maxInt(u32)) {
        return vk.Extent2D{ .width = capabilities.current_extent.width, .height = capabilities.current_extent.height };
    } else {
        var width: c_int = 0;
        var height: c_int = 0;
        glfw.glfwGetFramebufferSize(window, &width, &height);

        var actualExtent = vk.Extent2D{
            .width = @intCast(u32, width),
            .height = @intCast(u32, height),
        };

        actualExtent.width = @intCast(u32, std.math.max(capabilities.min_image_extent.width, std.math.min(capabilities.max_image_extent.width, actualExtent.width)));
        actualExtent.height = @intCast(u32, std.math.max(capabilities.min_image_extent.height, std.math.min(capabilities.max_image_extent.height, actualExtent.height)));

        return actualExtent;
    }
}
