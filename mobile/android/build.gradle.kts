// Luduvo Android port — Qt6 + SDL3 + Vulkan (NDK)
plugins { id("com.android.application") }
android {
    namespace = "com.luduvo.client"
    compileSdk = 35
    defaultConfig {
        applicationId = "com.luduvo.client"
        minSdk = 28   // Vulkan 1.1 baseline
        targetSdk = 35
        externalNativeBuild { cmake { arguments += listOf("-DANDROID_STL=c++_shared", "-DLDV_PLATFORM=android") } }
    }
    externalNativeBuild { cmake { path = file("src/main/cpp/CMakeLists.txt") } }
}
