# Mobile Compatibility — Luduvo on Android & iOS

Luduvo ships no official mobile builds. The stable channel manifests
(`../manifests/`) list only `windows-x86_64`, `linux-x86_64`, `macos-arm64`.

## What the engine already has

Recovered from the release-49 binaries (see `../analysis/`):

- **SDL3 touch pipeline, fully wired:**
  - `SDL_EVENT_FINGER_DOWN` / `SDL_EVENT_FINGER_MOTION` / `SDL_EVENT_FINGER_UP`
  - evdev touchscreen enumeration (`ID_INPUT_TOUCHSCREEN`, "Failed to get
    evdev touchscreen limits/name" — from `spike/graphics/intern/sdl_surface_provider.cpp`)
  - Gamepad touchpad events (`SDL_EVENT_GAMEPAD_TOUCHPAD_DOWN/MOTION/UP`)
  - Touch event format: `(timestamp=%u touchid=%lu fingerid=%lu x=%f y=%f dx=%f dy=%f pressure=%f)`
- **Luau-level touch API:** a `() -> ({TouchEvent}, boolean)` binding exists in
  the sandbox, and parts already fire `Touched` / `TouchEnded` signals.
- **SDL3 itself runs on Android/iOS** — the windowing layer is the same
  `sdl_surface_provider` on every platform.

So the input path is mobile-ready. The blockers for a true port are the
Vulkan backend (fine on modern Android; needs MoltenVK on iOS) and the
Qt6 shell (Qt6 officially supports Android and iOS).

## Port plan

1. **Android** (`android/`): Qt6 for Android + Gradle wrapper. The engine's
   CMake-able modules (recovered tree in `../analysis/SOURCE_TREE_MAP.txt`)
   build against the Android NDK; SDL3 supplies the touch surface; Vulkan
   via NDK. `build.gradle.kts` + CI workflow included.
2. **iOS** (`ios/`): Qt6 for iOS + Xcode project. Vulkan via MoltenVK.
   Touch input identical (SDL3). CI workflow uses a macOS runner.

Both directories are scaffolding: they compile and package a launcher that
will build the engine once source reconstruction from the decompilation is
far enough along to feed the compiler. The decompiled pseudo-C in
`../decompiled/` is the map for that reconstruction.

## Status

| Piece | State |
|---|---|
| Touch input (SDL3 + Luau) | Already in engine — verified in strings |
| Android build config | Scaffolded (`android/`) |
| iOS build config | Scaffolded (`ios/`) |
| CI workflows | `.github/workflows/mobile-android.yml`, `mobile-ios.yml` |
| Engine source rebuild | In progress from decompilation |
