// luduvo_engine_api.h
// C ABI exposed by the native Luduvo engine (libluduvo.dylib).
//
// The engine is loaded at runtime rather than linked at build time so that
// the iOS client can ship without a proprietary engine binary. This header
// declares the ABI plus a loader that resolves the symbols dynamically.
#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Loads libluduvo.dylib if it is present in the app bundle and resolves the
// engine entry points. Returns the dlopen handle, or NULL when the engine
// library is not bundled (the client then runs in "shell only" mode).
void *ldv_engine_load_library(void);

// True when a real engine library was found and bound.
int ldv_engine_available(void);

int ldv_engine_init(const char *config_path);
void ldv_engine_shutdown(void);
void ldv_engine_tick(float dt);
void ldv_engine_resize(int width, int height);

void ldv_input_finger_down(uint64_t timestamp, int touch_id, int finger_id, float x, float y, float pressure);
void ldv_input_finger_motion(uint64_t timestamp, int touch_id, int finger_id, float x, float y, float dx, float dy, float pressure);
void ldv_input_finger_up(uint64_t timestamp, int touch_id, int finger_id, float x, float y, float pressure);

void ldv_input_gamepad_touchpad_down(uint32_t touchpad, uint32_t finger, uint32_t button, float x, float y, float pressure);
void ldv_input_gamepad_touchpad_motion(uint32_t touchpad, uint32_t finger, uint32_t button, float x, float y, float dx, float dy, float pressure);
void ldv_input_gamepad_touchpad_up(uint32_t touchpad, uint32_t finger, uint32_t button, float x, float y, float pressure);

void ldv_input_key_down(int scancode, int keycode, int modifiers);
void ldv_input_key_up(int scancode, int keycode, int modifiers);
void ldv_input_text(const char *text);

void ldv_input_focus_lost(void);
void ldv_input_focus_gained(void);

#ifdef __cplusplus
}
#endif
