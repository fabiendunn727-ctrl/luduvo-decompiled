# Engine modules recovered from SOURCE_TREE_MAP.txt (spike/*, server/*)
# Rebuild targets: LuduvoGame (client), LuduvoEditor (studio)
cmake_minimum_required(VERSION 3.22)
project(luduvo-engine CXX)
set(CMAKE_CXX_STANDARD 20)
# SDL3 touch surface + Vulkan backend + flecs ECS + Luau runtime
add_subdirectory(sdl3)
add_subdirectory(luau)
add_subdirectory(flecs)
add_library(luduvo SHARED engine_jni.cpp)  # JNI surface: SDL_EVENT_FINGER_* -> engine input
target_link_libraries(luduvo SDL3::SDL3 luau flecs::flecs vulkan android log)
