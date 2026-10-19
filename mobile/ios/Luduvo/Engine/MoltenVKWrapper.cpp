// MoltenVKWrapper.cpp
// Vulkan-to-Metal translation layer for the iOS client.
//
// The engine's Vulkan backend (spike/graphics/intern/vulkan) talks plain
// Vulkan. On iOS that is served by MoltenVK, a static library linked into
// the app. This file provides the platform glue the engine needs:
// instance/device creation and the CAMetalLayer-backed swapchain.
//
// The surface is created with the portable VK_EXT_metal_surface extension
// directly against the CAMetalLayer owned by the MTKView, so the app keeps
// a single render target.

#include "MoltenVKWrapper.hpp"

#include <vulkan/vulkan_metal.h>

#include <cstring>

namespace {

// The Metal layer is handed across the Objective-C boundary as a void*.
const CAMetalLayer *asMetalLayer(void *ptr) {
    return reinterpret_cast<const CAMetalLayer *>(ptr);
}

} // namespace

extern "C" {

VkResult ldv_moltenvk_initialize(VkInstance *instance,
                                  VkPhysicalDevice *physicalDevice,
                                  VkDevice *device,
                                  VkQueue *graphicsQueue) {
    if (!instance || !physicalDevice || !device || !graphicsQueue) {
        return VK_ERROR_INITIALIZATION_FAILED;
    }

    VkApplicationInfo appInfo = {};
    appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    appInfo.pApplicationName = "Luduvo";
    appInfo.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.pEngineName = "Luduvo";
    appInfo.engineVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.apiVersion = VK_API_VERSION_1_3;

    const char *extensions[] = {
        VK_EXT_METAL_SURFACE_EXTENSION_NAME,
    };

    VkInstanceCreateInfo instanceInfo = {};
    instanceInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    instanceInfo.pApplicationInfo = &appInfo;
    instanceInfo.enabledExtensionCount = 1;
    instanceInfo.ppEnabledExtensionNames = extensions;

    VkInstance createdInstance = VK_NULL_HANDLE;
    VkResult result = vkCreateInstance(&instanceInfo, nullptr, &createdInstance);
    if (result != VK_SUCCESS) {
        return result;
    }

    // Pick the first physical device and its graphics queue family.
    uint32_t deviceCount = 0;
    vkEnumeratePhysicalDevices(createdInstance, &deviceCount, nullptr);
    if (deviceCount == 0) {
        vkDestroyInstance(createdInstance, nullptr);
        return VK_ERROR_INITIALIZATION_FAILED;
    }

    VkPhysicalDevice *devices = new VkPhysicalDevice[deviceCount];
    vkEnumeratePhysicalDevices(createdInstance, &deviceCount, devices);

    VkPhysicalDevice selected = devices[0];
    delete[] devices;

    uint32_t queueFamilyCount = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(selected, &queueFamilyCount, nullptr);

    VkQueueFamilyProperties *families = new VkQueueFamilyProperties[queueFamilyCount];
    vkGetPhysicalDeviceQueueFamilyProperties(selected, &queueFamilyCount, families);

    uint32_t graphicsFamily = UINT32_MAX;
    for (uint32_t i = 0; i < queueFamilyCount; i++) {
        if (families[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) {
            graphicsFamily = i;
            break;
        }
    }
    delete[] families;

    if (graphicsFamily == UINT32_MAX) {
        vkDestroyInstance(createdInstance, nullptr);
        return VK_ERROR_INITIALIZATION_FAILED;
    }

    float queuePriority = 1.0f;
    VkDeviceQueueCreateInfo queueInfo = {};
    queueInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queueInfo.queueFamilyIndex = graphicsFamily;
    queueInfo.queueCount = 1;
    queueInfo.pQueuePriorities = &queuePriority;

    VkPhysicalDeviceFeatures features = {};
    VkDeviceCreateInfo deviceInfo = {};
    deviceInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    deviceInfo.queueCreateInfoCount = 1;
    deviceInfo.pQueueCreateInfos = &queueInfo;
    deviceInfo.pEnabledFeatures = &features;

    VkDevice createdDevice = VK_NULL_HANDLE;
    result = vkCreateDevice(selected, &deviceInfo, nullptr, &createdDevice);
    if (result != VK_SUCCESS) {
        vkDestroyInstance(createdInstance, nullptr);
        return result;
    }

    VkQueue createdQueue = VK_NULL_HANDLE;
    vkGetDeviceQueue(createdDevice, graphicsFamily, 0, &createdQueue);

    *instance = createdInstance;
    *physicalDevice = selected;
    *device = createdDevice;
    *graphicsQueue = createdQueue;

    return VK_SUCCESS;
}

VkResult ldv_moltenvk_create_surface(VkInstance instance, void *metalLayer, VkSurfaceKHR *surface) {
    if (instance == VK_NULL_HANDLE || !metalLayer || !surface) {
        return VK_ERROR_INITIALIZATION_FAILED;
    }

    VkMetalSurfaceCreateInfoEXT surfaceInfo = {};
    surfaceInfo.sType = VK_STRUCTURE_TYPE_METAL_SURFACE_CREATE_INFO_EXT;
    surfaceInfo.pLayer = asMetalLayer(metalLayer);

    VkSurfaceKHR createdSurface = VK_NULL_HANDLE;
    VkResult result = vkCreateMetalSurfaceEXT(instance, &surfaceInfo, nullptr, &createdSurface);
    if (result != VK_SUCCESS) {
        return result;
    }

    *surface = createdSurface;
    return VK_SUCCESS;
}

VkResult ldv_moltenvk_create_swapchain(VkDevice device,
                                        VkPhysicalDevice physicalDevice,
                                        VkSurfaceKHR surface,
                                        VkSwapchainKHR *swapchain,
                                        uint32_t *imageCount,
                                        VkFormat *imageFormat,
                                        VkExtent2D *extent) {
    if (!swapchain || !imageCount || !imageFormat || !extent) {
        return VK_ERROR_INITIALIZATION_FAILED;
    }

    VkSurfaceCapabilitiesKHR capabilities = {};
    if (vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface, &capabilities) != VK_SUCCESS) {
        return VK_ERROR_INITIALIZATION_FAILED;
    }

    uint32_t count = capabilities.minImageCount == 0 ? 2 : capabilities.minImageCount + 1;
    if (capabilities.maxImageCount > 0 && count > capabilities.maxImageCount) {
        count = capabilities.maxImageCount;
    }

    uint32_t formatCount = 1;
    VkSurfaceFormatKHR surfaceFormat = {};
    vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, &formatCount, &surfaceFormat);
    if (surfaceFormat.format == VK_FORMAT_UNDEFINED) {
        surfaceFormat = { VK_FORMAT_B8G8R8A8_SRGB, VK_COLOR_SPACE_SRGB_NONLINEAR_KHR };
    }

    VkExtent2D chosenExtent = capabilities.currentExtent;
    if (chosenExtent.width == UINT32_MAX) {
        chosenExtent = extent->width > 0 ? *extent : capabilities.maxImageExtent;
    }

    VkSwapchainCreateInfoKHR swapchainInfo = {};
    swapchainInfo.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    swapchainInfo.surface = surface;
    swapchainInfo.minImageCount = count;
    swapchainInfo.imageFormat = surfaceFormat.format;
    swapchainInfo.imageColorSpace = surfaceFormat.colorSpace;
    swapchainInfo.imageExtent = chosenExtent;
    swapchainInfo.imageArrayLayers = 1;
    swapchainInfo.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT;
    swapchainInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
    swapchainInfo.preTransform = capabilities.currentTransform;
    swapchainInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    swapchainInfo.presentMode = VK_PRESENT_MODE_FIFO_KHR;
    swapchainInfo.clipped = VK_TRUE;
    swapchainInfo.oldSwapchain = VK_NULL_HANDLE;

    VkSwapchainKHR createdSwapchain = VK_NULL_HANDLE;
    VkResult result = vkCreateSwapchainKHR(device, &swapchainInfo, nullptr, &createdSwapchain);
    if (result != VK_SUCCESS) {
        return result;
    }

    *swapchain = createdSwapchain;
    *imageCount = count;
    *imageFormat = surfaceFormat.format;
    *extent = chosenExtent;

    return VK_SUCCESS;
}

VkResult ldv_moltenvk_acquire_next_image(VkDevice device,
                                          VkSwapchainKHR swapchain,
                                          uint64_t timeout,
                                          VkSemaphore semaphore,
                                          VkFence fence,
                                          uint32_t *imageIndex) {
    return vkAcquireNextImageKHR(device, swapchain, timeout, semaphore, fence, imageIndex);
}

VkResult ldv_moltenvk_present(VkQueue queue,
                               VkSwapchainKHR swapchain,
                               uint32_t imageIndex,
                               VkSemaphore waitSemaphore) {
    VkPresentInfoKHR presentInfo = {};
    presentInfo.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
    presentInfo.waitSemaphoreCount = waitSemaphore != VK_NULL_HANDLE ? 1 : 0;
    presentInfo.pWaitSemaphores = waitSemaphore != VK_NULL_HANDLE ? &waitSemaphore : nullptr;
    presentInfo.swapchainCount = 1;
    presentInfo.pSwapchains = &swapchain;
    presentInfo.pImageIndices = &imageIndex;

    return vkQueuePresentKHR(queue, &presentInfo);
}

void ldv_moltenvk_cleanup(VkDevice device,
                          VkSwapchainKHR swapchain,
                          VkSurfaceKHR surface,
                          VkInstance instance) {
    if (device != VK_NULL_HANDLE) {
        if (swapchain != VK_NULL_HANDLE) {
            vkDestroySwapchainKHR(device, swapchain, nullptr);
        }
        vkDestroyDevice(device, nullptr);
    }
    if (instance != VK_NULL_HANDLE) {
        if (surface != VK_NULL_HANDLE) {
            vkDestroySurfaceKHR(instance, surface, nullptr);
        }
        vkDestroyInstance(instance, nullptr);
    }
}

} // extern "C"

namespace ldv {
namespace moltenvk {

bool Swapchain::initialize(void *metalLayer, uint32_t width, uint32_t height) {
    if (!metalLayer) {
        return false;
    }

    VkInstance instance = VK_NULL_HANDLE;
    VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
    VkDevice device = VK_NULL_HANDLE;
    VkQueue graphicsQueue = VK_NULL_HANDLE;
    VkSurfaceKHR surface = VK_NULL_HANDLE;

    VkResult result = ldv_moltenvk_initialize(&instance, &physicalDevice, &device, &graphicsQueue);
    if (result != VK_SUCCESS) {
        return false;
    }

    result = ldv_moltenvk_create_surface(instance, metalLayer, &surface);
    if (result != VK_SUCCESS) {
        vkDestroyDevice(device, nullptr);
        vkDestroyInstance(instance, nullptr);
        return false;
    }

    instance_ = instance;
    physicalDevice_ = physicalDevice;
    device_ = device;
    graphicsQueue_ = graphicsQueue;
    surface_ = surface;

    VkExtent2D desiredExtent = { width, height };
    result = ldv_moltenvk_create_swapchain(device_, physicalDevice_, surface_,
                                           &swapchain_, &imageCount_, &format_, &desiredExtent);
    if (result != VK_SUCCESS) {
        ldv_moltenvk_cleanup(device_, VK_NULL_HANDLE, surface_, instance_);
        return false;
    }

    extent_ = desiredExtent;
    return true;
}

void Swapchain::cleanup() {
    if (device_ != VK_NULL_HANDLE) {
        if (swapchain_ != VK_NULL_HANDLE) {
            vkDestroySwapchainKHR(device_, swapchain_, nullptr);
        }
    }
    if (instance_ != VK_NULL_HANDLE) {
        if (surface_ != VK_NULL_HANDLE) {
            vkDestroySurfaceKHR(instance_, surface_, nullptr);
        }
        if (device_ != VK_NULL_HANDLE) {
            vkDestroyDevice(device_, nullptr);
        }
        vkDestroyInstance(instance_, nullptr);
    }
    swapchain_ = VK_NULL_HANDLE;
    surface_ = VK_NULL_HANDLE;
    device_ = VK_NULL_HANDLE;
    instance_ = VK_NULL_HANDLE;
    graphicsQueue_ = VK_NULL_HANDLE;
    physicalDevice_ = VK_NULL_HANDLE;
    imageCount_ = 0;
    format_ = VK_FORMAT_UNDEFINED;
    extent_ = {0, 0};
}

bool Swapchain::resize(uint32_t width, uint32_t height) {
    if (device_ == VK_NULL_HANDLE || surface_ == VK_NULL_HANDLE) {
        return false;
    }

    // Recreate the swapchain for the new extent.
    if (swapchain_ != VK_NULL_HANDLE) {
        vkDestroySwapchainKHR(device_, swapchain_, nullptr);
        swapchain_ = VK_NULL_HANDLE;
    }

    VkExtent2D desiredExtent = { width, height };
    VkResult result = ldv_moltenvk_create_swapchain(device_, physicalDevice_, surface_,
                                                     &swapchain_, &imageCount_, &format_,
                                                     &desiredExtent);
    if (result != VK_SUCCESS) {
        return false;
    }

    extent_ = desiredExtent;
    return true;
}

VkResult Swapchain::acquireNextImage(uint64_t timeout, VkSemaphore semaphore,
                                      VkFence fence, uint32_t *imageIndex) {
    if (device_ == VK_NULL_HANDLE) {
        return VK_ERROR_INITIALIZATION_FAILED;
    }
    return ldv_moltenvk_acquire_next_image(device_, swapchain_, timeout, semaphore, fence, imageIndex);
}

VkResult Swapchain::present(VkQueue queue, VkSemaphore waitSemaphore) {
    if (device_ == VK_NULL_HANDLE) {
        return VK_ERROR_INITIALIZATION_FAILED;
    }
    return ldv_moltenvk_present(queue, swapchain_, 0, waitSemaphore);
}

} // namespace moltenvk
} // namespace ldv
