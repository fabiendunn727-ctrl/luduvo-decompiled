// EngineBridge.cpp - Connects Luduvo engine to iOS/MoltenVK platform layer
#include "MoltenVKWrapper.hpp"
#include <SDL3/SDL.h>
#include <metal/Metal.hpp>
#include <iostream>

namespace ldv {
namespace platform {

class iOSPlatform {
public:
    iOSPlatform() = default;
    ~iOSPlatform() { shutdown(); }

    bool initialize(void* metalLayer, uint32_t width, uint32_t height) {
        // Initialize SDL for iOS
        if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD | SDL_INIT_EVENTS) != 0) {
            std::cerr << "SDL_Init failed: " << SDL_GetError() << std::endl;
            return false;
        }

        // Create SDL window backed by the Metal layer
        window_ = SDL_CreateWindow("Luduvo", width, height, SDL_WINDOW_METAL | SDL_WINDOW_HIDDEN);
        if (!window_) {
            std::cerr << "SDL_CreateWindow failed: " << SDL_GetError() << std::endl;
            return false;
        }

        // Get the Metal layer from the window
        metalLayer_ = static_cast<CAMetalLayer*>(SDL_GetWindowMetalLayer(window_));
        if (!metalLayer_) {
            std::cerr << "Failed to get Metal layer from SDL window" << std::endl;
            return false;
        }

        // Initialize MoltenVK swapchain
        if (!swapchain_.initialize(metalLayer_, width, height)) {
            std::cerr << "Failed to initialize MoltenVK swapchain" << std::endl;
            return false;
        }

        // Initialize engine's Vulkan backend with MoltenVK
        VkInstance instance = VK_NULL_HANDLE;
        VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
        VkDevice device = VK_NULL_HANDLE;
        VkQueue graphicsQueue = VK_NULL_HANDLE;
        VkSurfaceKHR surface = VK_NULL_HANDLE;

        VkResult result = ldv_moltenvk_initialize(&instance, &physicalDevice, &device, &graphicsQueue, &surface);
        if (result != VK_SUCCESS) {
            std::cerr << "MoltenVK initialization failed: " << result << std::endl;
            return false;
        }

        instance_ = instance;
        physicalDevice_ = physicalDevice;
        device_ = device;
        graphicsQueue_ = graphicsQueue;
        surface_ = surface;

        // Create swapchain
        result = ldv_moltenvk_create_swapchain(device, physicalDevice, surface, &swapchain_, &imageCount_, &format_, &extent_);
        if (result != VK_SUCCESS) {
            std::cerr << "Swapchain creation failed: " << result << std::endl;
            return false;
        }

        initialized_ = true;
        return true;
    }

    void shutdown() {
        if (initialized_) {
            ldv_moltenvk_cleanup(device_, swapchain_, surface_, instance_);
            if (window_) {
                SDL_DestroyWindow(window_);
                window_ = nullptr;
            }
            SDL_Quit();
            initialized_ = false;
        }
    }

    void resize(uint32_t width, uint32_t height) {
        if (!initialized_) return;
        // Recreate swapchain
        ldv_moltenvk_cleanup(device_, swapchain_, surface_, instance_);
        VkResult result = ldv_moltenvk_create_swapchain(device_, physicalDevice_, surface_, &swapchain_, &imageCount_, &format_, &extent_);
        if (result != VK_SUCCESS) {
            std::cerr << "Swapchain resize failed: " << result << std::endl;
        }
    }

    void presentFrame(VkQueue queue, VkSemaphore waitSemaphore) {
        if (!initialized_) return;
        ldv_moltenvk_present(queue, swapchain_, currentImageIndex_, waitSemaphore);
    }

    void handleEvent(const SDL_Event* event) {
        // Forward SDL events to engine input system
        // Touch events are handled by the engine's SDL3 touch pipeline
    }

private:
    bool initialized_ = false;
    SDL_Window* window_ = nullptr;
    CAMetalLayer* metalLayer_ = nullptr;
    VkInstance instance_ = VK_NULL_HANDLE;
    VkPhysicalDevice physicalDevice_ = VK_NULL_HANDLE;
    VkDevice device_ = VK_NULL_HANDLE;
    VkQueue graphicsQueue_ = VK_NULL_HANDLE;
    VkSurfaceKHR surface_ = VK_NULL_HANDLE;
    VkSwapchainKHR swapchain_ = VK_NULL_HANDLE;
    VkFormat format_ = VK_FORMAT_UNDEFINED;
    VkExtent2D extent_ = {0, 0};
    uint32_t imageCount_ = 0;
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

void ldv_platform_handle_event(void* platform, const SDL_Event* event) {
    static_cast<ldv::platform::iOSPlatform*>(platform)->handleEvent(event);
}

} // extern "C"