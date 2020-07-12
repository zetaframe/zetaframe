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
    const Image = struct {
        context: *const Context,

        image: vk.Image,
        view: vk.ImageView,

        acquired: vk.Semaphore,
        presented: vk.Semaphore,

        fence: vk.Fence,

        fn init(context: *const Context, image: vk.Image, format: vk.Format) !Image {
            const view = try context.vkd.createImageView(context.device, .{
                .image = image,
                .view_type = .@"2d",
                .format = format,
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
            }, null);
            errdefer context.vkd.destroyImageView(context.device, view, null);

            const acquired = try context.vkd.createSemaphore(context.device, .{ .flags = .{} }, null);
            errdefer context.vkd.destroySemaphore(context.device, acquired, null);

            const presented = try context.vkd.createSemaphore(context.device, .{ .flags = .{} }, null);
            errdefer context.vkd.destroySemaphore(context.device, presented, null);

            const fence = try context.vkd.createFence(context.device, .{ .flags = .{ .signaled_bit = true } }, null);
            errdefer context.vkd.destroyFence(context.device, fence, null);

            return Image{
                .context = context,

                .image = image,
                .view = view,

                .acquired = acquired,
                .presented = presented,

                .fence = fence,
            };
        }

        fn deinit(self: Image) void {
            self.waitForFence() catch unreachable;
            self.context.vkd.destroyFence(self.context.device, self.fence, null);
            self.context.vkd.destroySemaphore(self.context.device, self.presented, null);
            self.context.vkd.destroySemaphore(self.context.device, self.acquired, null);
            self.context.vkd.destroyImageView(self.context.device, self.view, null);
        }

        pub fn waitForFence(self: Image) !void {
            _ = try self.context.vkd.waitForFences(self.context.device, 1, @ptrCast([*]const vk.Fence, &self.fence), vk.TRUE, std.math.maxInt(u64));
        }
    };

    const Self = @This();
    allocator: *Allocator,

    swapchain: vk.SwapchainKHR,

    context: *const Context,
    window: *windowing.Window,

    images: []Image,

    present_mode: vk.PresentModeKHR,
    image_format: vk.Format,
    extent: vk.Extent2D,

    pub fn new() Self {
        return Self{
            .allocator = undefined,

            .swapchain = undefined,

            .context = undefined,
            .window = undefined,

            .images = undefined,

            .present_mode = undefined,
            .image_format = undefined,
            .extent = undefined,
        };
    }

    pub fn init(self: *Self, allocator: *Allocator, context: *const Context, window: *windowing.Window) !vk.Semaphore {
        self.allocator = allocator;

        self.context = context;
        self.window = window;

        try self.createSwapchain(.null_handle);
        try self.createImages();

        var acquiredNext = try context.vkd.createSemaphore(context.device, .{ .flags = .{} }, null);
        errdefer context.vkd.destroySemaphore(context.device, acquiredNext, null);

        if (context.vkd.acquireNextImageKHR(context.device, self.swapchain, std.math.maxInt(u64), acquiredNext, .null_handle)) |result| {
            std.mem.swap(vk.Semaphore, &self.images[result.image_index].acquired, &acquiredNext);
            return acquiredNext;
        } else |err| return VulkanError.AcquireImageFailed;
    }

    pub fn recreate(self: *Self) !vk.Semaphore {
        self.deinitNoSwapchain();
        try self.createSwapchain(self.swapchain);
        try self.createImages();

        var acquiredNext = try self.context.vkd.createSemaphore(self.context.device, .{ .flags = .{} }, null);
        errdefer self.context.vkd.destroySemaphore(self.context.device, acquiredNext, null);

        if (self.context.vkd.acquireNextImageKHR(self.context.device, self.swapchain, std.math.maxInt(u64), acquiredNext, .null_handle)) |result| {
            std.mem.swap(vk.Semaphore, &self.images[result.image_index].acquired, &acquiredNext);
            return acquiredNext;
        } else |err| return VulkanError.AcquireImageFailed;
    }

    fn deinitNoSwapchain(self: *Self) void {
        for (self.images) |image| image.deinit();
        self.allocator.free(self.images);
    }

    pub fn deinit(self: *Self) void {
        self.deinitNoSwapchain();

        self.context.vkd.destroySwapchainKHR(self.context.device, self.swapchain, null);
    }

    pub fn acquireNextImage(self: *Self, semaphore: vk.Semaphore, imageIndex: *u32) !bool {
        if (self.context.vkd.acquireNextImageKHR(self.context.device, self.swapchain, std.math.maxInt(u64), semaphore, .null_handle)) |result| {
            imageIndex.* = result.image_index;
            return false;
        } else |err| switch (err) {
            error.OutOfDateKHR => return true,
            else => return VulkanError.AcquireImageFailed,
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

        if (self.context.vkd.queuePresentKHR(self.context.present_queue, presentInfo)) |result| {
            return false;
        } else |err| switch (err) {
            error.OutOfDateKHR => return true,
            else => return VulkanError.PresentFailed,
        }
    }

    fn createSwapchain(self: *Self, old: vk.SwapchainKHR) !void {
        const surfaceFormat = try self.chooseSurfaceFormat();
        const presentMode = try self.choosePresentMode();
        const extent = try self.findActualExtent();

        const capabilities = try self.context.vki.getPhysicalDeviceSurfaceCapabilitiesKHR(self.context.physical_device, self.context.surface);

        var imageCount: u32 = capabilities.min_image_count + 1;
        if (capabilities.max_image_count > 0) imageCount = std.math.min(imageCount, capabilities.max_image_count);

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

            .pre_transform = capabilities.current_transform,
            .composite_alpha = vk.CompositeAlphaFlagsKHR{ .opaque_bit_khr = true },

            .present_mode = presentMode,
            .clipped = vk.TRUE,

            .flags = .{},
            .old_swapchain = old,
        };

        self.swapchain = try self.context.vkd.createSwapchainKHR(self.context.device, createInfo, null);

        if (old != .null_handle) self.context.vkd.destroySwapchainKHR(self.context.device, old, null);

        self.present_mode = presentMode;
        self.image_format = surfaceFormat.format;
        self.extent = extent;
    }

    fn createImages(self: *Self) !void {
        var count: u32 = 0;
        _ = try self.context.vkd.getSwapchainImagesKHR(self.context.device, self.swapchain, &count, null);
        
        var vkImages = try self.allocator.alloc(vk.Image, count);
        defer self.allocator.free(vkImages);
        _ = try self.context.vkd.getSwapchainImagesKHR(self.context.device, self.swapchain, &count, vkImages.ptr);
        
        self.images = try self.allocator.alloc(Image, count);
        errdefer self.allocator.free(self.images);

        var i: usize = 0;
        errdefer for (self.images[0..i]) |image| image.deinit();

        for (vkImages) |vkImage| {
            self.images[i] = try Image.init(self.context, vkImage, self.image_format);
            i += 1;
        }
    }

    fn chooseSurfaceFormat(self: *Self) !vk.SurfaceFormatKHR {
        const preferred = [_]vk.SurfaceFormatKHR{.{
            .format = .b8g8r8a8_srgb,
            .color_space = .srgb_nonlinear_khr,
        }};

        var count: u32 = 0;
        _ = try self.context.vki.getPhysicalDeviceSurfaceFormatsKHR(self.context.physical_device, self.context.surface, &count, null);

        var availableFormats = try self.allocator.alloc(vk.SurfaceFormatKHR, count);
        defer self.allocator.free(availableFormats);
        _ = try self.context.vki.getPhysicalDeviceSurfaceFormatsKHR(self.context.physical_device, self.context.surface, &count, availableFormats.ptr);

        for (preferred) |format| for (availableFormats) |availableFormat| if (std.meta.eql(format, availableFormat)) return format;

        return availableFormats[0];
    }

    fn choosePresentMode(self: *Self) !vk.PresentModeKHR {
        const preferred = [_]vk.PresentModeKHR{
            .mailbox_khr,
            .immediate_khr,
        };

        var count: u32 = 0;
        _ = try self.context.vki.getPhysicalDeviceSurfacePresentModesKHR(self.context.physical_device, self.context.surface, &count, null);

        var availablePresentModes = try self.allocator.alloc(vk.PresentModeKHR, count);
        defer self.allocator.free(availablePresentModes);
        _ = try self.context.vki.getPhysicalDeviceSurfacePresentModesKHR(self.context.physical_device, self.context.surface, &count, availablePresentModes.ptr);

        for (preferred) |mode| if (std.mem.indexOfScalar(vk.PresentModeKHR, availablePresentModes, mode) != null) return mode;

        return .fifo_khr;
    }

    fn findActualExtent(self: *Self) !vk.Extent2D {
        const capabilities = try self.context.vki.getPhysicalDeviceSurfaceCapabilitiesKHR(self.context.physical_device, self.context.surface);

        if (capabilities.current_extent.width != std.math.maxInt(u32)) {
            return vk.Extent2D{ .width = capabilities.current_extent.width, .height = capabilities.current_extent.height };
        } else {
            var width: c_int = 0;
            var height: c_int = 0;
            glfw.glfwGetFramebufferSize(self.window.window, &width, &height);

            var actualExtent = vk.Extent2D{
                .width = @intCast(u32, width),
                .height = @intCast(u32, height),
            };

            actualExtent.width = @intCast(u32, std.math.max(capabilities.min_image_extent.width, std.math.min(capabilities.max_image_extent.width, actualExtent.width)));
            actualExtent.height = @intCast(u32, std.math.max(capabilities.min_image_extent.height, std.math.min(capabilities.max_image_extent.height, actualExtent.height)));

            return actualExtent;
        }
    }
};
