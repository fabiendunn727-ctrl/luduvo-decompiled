// EngineBridge.cpp - Connects Luduvo engine to iOS/MoltenVK platform layer
//
// The iOS client owns its own UIWindow and MTKView, so the platform layer
// does not create an SDL window. It talks to the Vulkan backend through
// MoltenVK, using the CAMetalLayer owned by the MTKView as the surface.

#include "MoltenVKWrapper.hpp"

#include <cstdint>

namespace ldv {
namespace platform {

class iOSPlatform {
public:
    iOSPlatform() = default;
    ~iOSPlatform() { shutdown(); }

    bool initialize(void* metalLayer, uint32_t width, uint32_t height) {
        if (!metalLayer) {
            return false;
        }

        // Initialize the engine's Vulkan backend with MoltenVK
        VkInstance instance = VK_NULL_HANDLE;
        VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
        VkDevice device = VK_NULL_HANDLE;
        VkQueue graphicsQueue = VK_NULL_HANDLE;
        VkSurfaceKHR surface = VK_NULL_HANDLE;

        VkResult result = ldv_moltenvk_initialize(&instance, &physicalDevice, &device,
                                                  &graphicsQueue);
        if (result != VK_SUCCESS) {
            return false;
        }

        instance_ = instance;
        physicalDevice_ = physicalDevice;
        device_ = device;
        graphicsQueue_ = graphicsQueue;

        // Create the surface for the CAMetalLayer owned by the MTKView
        result = ldv_moltenvk_create_surface(instance, metalLayer, &surface);
        if (result != VK_SUCCESS) {
            ldv_moltenvk_cleanup(device, VK_NULL_HANDLE, VK_NULL_HANDLE, instance);
            return false;
        }
        surface_ = surface;

        // Initialize MoltenVK swapchain
        if (!swapchain_.initialize(metalLayer, width, height)) {
            ldv_moltenvk_cleanup(device, VK_NULL_HANDLE, surface, instance);
            return false;
        }

        initialized_ = true;
        return true;
    }

    void shutdown() {
        if (initialized_) {
            swapchain_.cleanup();
            ldv_moltenvk_cleanup(device_, VK_NULL_HANDLE, surface_, instance_);
            initialized_ = false;
        }
    }

    void resize(uint32_t width, uint32_t height) {
        if (!initialized_) return;
        swapchain_.resize(width, height);
    }

    void presentFrame(VkQueue queue, VkSemaphore waitSemaphore) {
        if (!initialized_) return;
        ldv_moltenvk_present(queue, swapchain_.get(), currentImageIndex_, waitSemaphore);
    }

    void acquireFrame(VkSemaphore semaphore, uint32_t* imageIndex) {
        if (!initialized_) return;
        ldv_moltenvk_acquire_next_image(device_, swapchain_.get(), UINT64_MAX,
                                        semaphore, VK_NULL_HANDLE, imageIndex);
        currentImageIndex_ = *imageIndex;
    }

private:
    bool initialized_ = false;
    VkInstance instance_ = VK_NULL_HANDLE;
    VkPhysicalDevice physicalDevice_ = VK_NULL_HANDLE;
    VkDevice device_ = VK_NULL_HANDLE;
    VkQueue graphicsQueue_ = VK_NULL_HANDLE;
    VkSurfaceKHR surface_ = VK_NULL_HANDLE;
    uint32_t currentImageIndex_ = 0;
    moltenvk::Swapchain swapchain_;
};

} // namespace platform
} // namespace ldv

// C interface for engine
extern "C" {

void* ldv_platform_create() {
    return new ldv::platform::iOSPlatform();
}

bool ldv_platform_initialize(void* platform, void* metalLayer, uint32_t width, uint32_t height) {
    return static_cast<ldv::platform::iOSPlatform*>(platform)->initialize(metalLayer, width, height);
}

void ldv_platform_shutdown(void* platform) {
    static_cast<ldv::platform::iOSPlatform*>(platform)->shutdown();
}

void ldv_platform_resize(void* platform, uint32_t width, uint32_t height) {
    static_cast<ldv::platform::iOSPlatform*>(platform)->resize(width, height);
}

void ldv_platform_present(void* platform, VkQueue queue, VkSemaphore waitSemaphore) {
    static_cast<ldv::platform::iOSPlatform*>(platform)->presentFrame(queue, waitSemaphore);
}

} // extern "C"
