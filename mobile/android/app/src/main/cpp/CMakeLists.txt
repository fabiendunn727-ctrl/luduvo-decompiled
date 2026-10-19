# Luduvo Engine Android Build — Native Engine from Decompiled Source
# Builds: libluduvo.so (client) + libluduvo_editor.so (studio)
cmake_minimum_required(VERSION 3.22)
project(luduvo-engine CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Platform config
if(NOT DEFINED LDV_PLATFORM)
    set(LDV_PLATFORM "android" CACHE STRING "Target platform")
endif()

if(LDV_PLATFORM STREQUAL "android")
    add_definitions(-DLDV_PLATFORM_ANDROID -DLDV_ENABLE_VULKAN=1)
    # Android log support
    find_library(ANDROID_LOG log)
    find_library(ANDROID_NATIVE_APP_GLUE android_native_app_glue)
    find_library(ANDROID_EGL EGL)
    find_library(ANDROID_GLES GLESv3)
endif()

# ---- SDL3 ----
# Fetch SDL3 from source or use system package
# For Android, we build SDL3 from source as part of the build
set(SDL3_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/SDL3" CACHE PATH "SDL3 source directory")

if(EXISTS "${SDL3_SOURCE_DIR}/CMakeLists.txt")
    add_subdirectory("${SDL3_SOURCE_DIR}" sdl3-build)
else()
    # Fallback: find_package if prebuilt
    find_package(SDL3 REQUIRED CONFIG)
endif()

# ---- Dependencies: flecs, luau, vulkan ----
# These are fetched via FetchContent or built from source
include(FetchContent)

# flecs ECS
FetchContent_Declare(
    flecs
    GIT_REPOSITORY https://github.com/SanderMertens/flecs
    GIT_TAG        v4.0.2
    GIT_SHALLOW    TRUE
)
FetchContent_MakeAvailable(flecs)

# Luau VM
FetchContent_Declare(
    luau
    GIT_REPOSITORY https://github.com/luau-lang/luau
    GIT_TAG        0.636
    GIT_SHALLOW    TRUE
)
FetchContent_MakeAvailable(luau)

# Vulkan headers/loader (Android NDK provides these)
find_package(Vulkan REQUIRED)

# ---- Engine modules from decompiled source ----
# Source root from decompiled analysis
set(LUDUVO_DECOMPILED_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../decompiled/linux" CACHE PATH "Decompiled engine source root")
set(LUDUVO_SPIKE_ROOT "${LUDUVO_DECOMPILED_ROOT}/spike" CACHE PATH "Spike engine modules")
set(LUDUVO_SERVER_ROOT "${LUDUVO_DECOMPILED_ROOT}/server" CACHE PATH "Server modules")
set(LUDUVO_APP_ROOT "${LUDUVO_DECOMPILED_ROOT}/app" CACHE PATH "App entry points")

# Verify source exists
if(NOT EXISTS "${LUDUVO_SPIKE_ROOT}")
    message(WARNING "Decompiled source not found at ${LUDUVO_SPIKE_ROOT} - using fallback stubs")
    # Create minimal stub for build to proceed
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/stub_engine.cpp" "
        #include <SDL3/SDL.h>
        extern \"C\" JNIEXPORT void JNICALL Java_com_luduvo_client_LuduvoEngine_nativeInit(JNIEnv*, jobject) {}
        extern \"C\" JNIEXPORT void JNICALL Java_com_luduvo_client_LuduvoEngine_nativeTick(JNIEnv*, jobject, jfloat) {}
        extern \"C\" JNIEXPORT void JNICALL Java_com_luduvo_client_LuduvoEngine_nativeTouch(JNIEnv*, jobject, jint, jfloat, jfloat, jint) {}
    ")
    add_library(luduvo SHARED "${CMAKE_CURRENT_BINARY_DIR}/stub_engine.cpp")
else()
    # ---- Engine library ----
    file(GLOB_RECURSE ENGINE_SOURCES
        "${LUDUVO_SPIKE_ROOT}/*.cpp"
        "${LUDUVO_SPIKE_ROOT}/*.c"
        "${LUDUVO_SERVER_ROOT}/*.cpp"
        "${LUDUVO_SERVER_ROOT}/*.c"
        "${LUDUVO_APP_ROOT}/*.cpp"
        "${LUDUVO_APP_ROOT}/*.c"
    )

    # Filter out editor-only and test files for client build
    list(FILTER ENGINE_SOURCES EXCLUDE REGEX ".*editor.*")
    list(FILTER ENGINE_SOURCES EXCLUDE REGEX ".*test.*")
    list(FILTER ENGINE_SOURCES EXCLUDE REGEX ".*benchmark.*")

    add_library(luduvo SHARED ${ENGINE_SOURCES} engine_jni.cpp)

    target_include_directories(luduvo PRIVATE
        "${LUDUVO_DECOMPILED_ROOT}"
        "${LUDUVO_SPIKE_ROOT}"
        "${LUDUVO_SERVER_ROOT}"
        "${LUDUVO_APP_ROOT}"
        "${SDL3_SOURCE_DIR}/include"
        "${luau_SOURCE_DIR}/include"
        "${flecs_SOURCE_DIR}/include"
    )

    target_link_libraries(luduvo PRIVATE
        SDL3::SDL3
        luau
        flecs::flecs
        ${ANDROID_LOG}
        ${ANDROID_NATIVE_APP_GLUE}
        ${ANDROID_EGL}
        ${ANDROID_GLES}
        Vulkan::Vulkan
        android
    )

    target_compile_definitions(luduvo PRIVATE
        LDV_PLATFORM_ANDROID
        LDV_ENABLE_VULKAN=1
        FLECS_STATIC
        LUAU_STATIC
    )
endif()

# ---- Editor library (separate build for studio) ----
if(EXISTS "${LUDUVO_DECOMPILED_ROOT}/LuduvoEditor")
    file(GLOB_RECURSE EDITOR_SOURCES
        "${LUDUVO_SPIKE_ROOT}/*.cpp"
        "${LUDUVO_SPIKE_ROOT}/*.c"
        "${LUDUVO_SERVER_ROOT}/*.cpp"
        "${LUDUVO_SERVER_ROOT}/*.c"
        "${LUDUVO_APP_ROOT}/*.cpp"
        "${LUDUVO_APP_ROOT}/*.c"
    )
    list(FILTER EDITOR_SOURCES INCLUDE REGEX ".*editor.*")

    add_library(luduvo_editor SHARED ${EDITOR_SOURCES} editor_jni.cpp)
    target_link_libraries(luduvo_editor PRIVATE luduvo)
    target_compile_definitions(luduvo_editor PRIVATE LDV_PLATFORM_ANDROID LDV_ENABLE_VULKAN=1)
endif()

# ---- Install targets for AAR ----
install(TARGETS luduvo luduvo_editor
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)