// MoltenVK Wrapper for Luduvo Engine
// Provides Vulkan-to-Metal translation layer
#pragma once

#include <vulkan/vulkan.h>
#include <MoltenVK/mvk_vulkan.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialize MoltenVK for the engine's Vulkan backend
VkResult ldv_moltenvk_initialize(VkInstance* instance, VkPhysicalDevice* physicalDevice, VkDevice* device, VkQueue* graphicsQueue, VkSurfaceKHR* surface);

// Create swapchain for iOS CAMetalLayer
VkResult ldv_moltenvk_create_swapchain(VkDevice device, VkPhysicalDevice physicalDevice, VkSurfaceKHR surface, VkSwapchainKHR* swapchain, uint32_t* imageCount, VkFormat* imageFormat, VkExtent2D* extent);

// Acquire next image
VkResult ldv_moltenvk_acquire_next_image(VkDevice device, VkSwapchainKHR swapchain, uint64_t timeout, VkSemaphore semaphore, VkFence fence, uint32_t* imageIndex);

// Present image
VkResult ldv_moltenvk_present(VkQueue queue, VkSwapchainKHR swapchain, uint32_t imageIndex, VkSemaphore waitSemaphore);

// Cleanup
void ldv_moltenvk_cleanup(VkDevice device, VkSwapchainKHR swapchain, VkSurfaceKHR surface, VkInstance instance);

#ifdef __cplusplus
}
#endif

// C++ helper class
namespace ldv {
namespace moltenvk {

class Swapchain {
public:
    Swapchain() = default;
    ~Swapchain() { cleanup(); }

    bool initialize(void* metalLayer, uint32_t width, uint32_t height);
    void cleanup();

    VkResult acquireNextImage(uint64_t timeout, VkSemaphore semaphore, VkFence fence, uint32_t* imageIndex);
    VkResult present(VkQueue queue, VkSemaphore waitSemaphore);

    VkSwapchainKHR get() const { return swapchain_; }
    VkFormat getFormat() const { return format_; }
    VkExtent2D getExtent() const { return extent_; }
    uint32_t getImageCount() const { return imageCount_; }

private:
    VkInstance instance_ = VK_NULL_HANDLE;
    VkPhysicalDevice physicalDevice_ = VK_NULL_HANDLE;
    VkDevice device_ = VK_NULL_HANDLE;
    VkQueue graphicsQueue_ = VK_NULL_HANDLE;
    VkSurfaceKHR surface_ = VK_NULL_HANDLE;
    VkSwapchainKHR swapchain_ = VK_NULL_HANDLE;
    VkFormat format_ = VK_FORMAT_UNDEFINED;
    VkExtent2D extent_ = {0, 0};
    uint32_t imageCount_ = 0;
};

} // namespace moltenvk
} // namespace ldv