// LuduvoEngineShim.m
//
// Resolves the native engine ABI (luduvo_engine_api.h) at runtime.
//
// The proprietary engine (libluduvo.dylib) is not part of this repository, so
// the client ships without it. When the dylib is present in the app bundle it
// is loaded and the real implementation is used; otherwise every entry point
// becomes a no-op and the app runs as a Metal/UIKit shell.

#import <Foundation/Foundation.h>
#import <dlfcn.h>

#import "luduvo_engine_api.h"

typedef int (*ldv_init_fn)(const char *);
typedef void (*ldv_void_fn)(void);
typedef void (*ldv_tick_fn)(float);
typedef void (*ldv_resize_fn)(int, int);
typedef void (*ldv_finger_down_fn)(uint64_t, int, int, float, float, float);
typedef void (*ldv_finger_motion_fn)(uint64_t, int, int, float, float, float, float, float);
typedef void (*ldv_finger_up_fn)(uint64_t, int, int, float, float, float);
typedef void (*ldv_touchpad_down_fn)(uint32_t, uint32_t, uint32_t, float, float, float);
typedef void (*ldv_touchpad_motion_fn)(uint32_t, uint32_t, uint32_t, float, float, float, float, float);
typedef void (*ldv_touchpad_up_fn)(uint32_t, uint32_t, uint32_t, float, float, float);
typedef void (*ldv_key_fn)(int, int, int);
typedef void (*ldv_text_fn)(const char *);

static void *g_handle = NULL;
static int g_attempted = 0;

static ldv_init_fn g_init = NULL;
static ldv_void_fn g_shutdown = NULL;
static ldv_tick_fn g_tick = NULL;
static ldv_resize_fn g_resize = NULL;
static ldv_finger_down_fn g_finger_down = NULL;
static ldv_finger_motion_fn g_finger_motion = NULL;
static ldv_finger_up_fn g_finger_up = NULL;
static ldv_touchpad_down_fn g_touchpad_down = NULL;
static ldv_touchpad_motion_fn g_touchpad_motion = NULL;
static ldv_touchpad_up_fn g_touchpad_up = NULL;
static ldv_key_fn g_key_down = NULL;
static ldv_key_fn g_key_up = NULL;
static ldv_text_fn g_text = NULL;

static void *g_lib = NULL;
static void *g_engine = NULL;

static void *resolve(const char *symbol) {
    if (!g_handle) return NULL;
    return dlsym(g_handle, symbol);
}

void *ldv_engine_load_library(void) {
    if (g_attempted) return g_handle;
    g_attempted = 1;

    // Try the app bundle first, then the locations the original client used.
    const char *candidates[] = {
        "@rpath/libluduvo.dylib",
        "libluduvo.dylib",
        "/usr/local/lib/libluduvo.dylib",
    };

    for (size_t i = 0; i < sizeof(candidates) / sizeof(candidates[0]); i++) {
        g_handle = dlopen(candidates[i], RTLD_LAZY | RTLD_LOCAL);
        if (g_handle) {
            NSLog(@"[LuduvoEngine] Loaded native engine: %s", candidates[i]);
            break;
        }
    }

    if (!g_handle) {
        NSLog(@"[LuduvoEngine] Native engine not found - running in shell mode");
        return NULL;
    }

    g_init = (ldv_init_fn)resolve("ldv_engine_init");
    g_shutdown = (ldv_void_fn)resolve("ldv_engine_shutdown");
    g_tick = (ldv_tick_fn)resolve("ldv_engine_tick");
    g_resize = (ldv_resize_fn)resolve("ldv_engine_resize");
    g_finger_down = (ldv_finger_down_fn)resolve("ldv_input_finger_down");
    g_finger_motion = (ldv_finger_motion_fn)resolve("ldv_input_finger_motion");
    g_finger_up = (ldv_finger_up_fn)resolve("ldv_input_finger_up");
    g_touchpad_down = (ldv_touchpad_down_fn)resolve("ldv_input_gamepad_touchpad_down");
    g_touchpad_motion = (ldv_touchpad_motion_fn)resolve("ldv_input_gamepad_touchpad_motion");
    g_touchpad_up = (ldv_touchpad_up_fn)resolve("ldv_input_gamepad_touchpad_up");
    g_key_down = (ldv_key_fn)resolve("ldv_input_key_down");
    g_key_up = (ldv_key_fn)resolve("ldv_input_key_up");
    g_text = (ldv_text_fn)resolve("ldv_input_text");

    return g_handle;
}

int ldv_engine_available(void) {
    return g_handle != NULL;
}

int ldv_engine_init(const char *config_path) {
    if (g_init) return g_init(config_path);
    return 0;
}

void ldv_engine_shutdown(void) {
    if (g_shutdown) g_shutdown();
}

void ldv_engine_tick(float dt) {
    if (g_tick) g_tick(dt);
}

void ldv_engine_resize(int width, int height) {
    if (g_resize) g_resize(width, height);
}

void ldv_input_finger_down(uint64_t timestamp, int touch_id, int finger_id, float x, float y, float pressure) {
    if (g_finger_down) g_finger_down(timestamp, touch_id, finger_id, x, y, pressure);
}

void ldv_input_finger_motion(uint64_t timestamp, int touch_id, int finger_id, float x, float y, float dx, float dy, float pressure) {
    if (g_finger_motion) g_finger_motion(timestamp, touch_id, finger_id, x, y, dx, dy, pressure);
}

void ldv_input_finger_up(uint64_t timestamp, int touch_id, int finger_id, float x, float y, float pressure) {
    if (g_finger_up) g_finger_up(timestamp, touch_id, finger_id, x, y, pressure);
}

void ldv_input_gamepad_touchpad_down(uint32_t touchpad, uint32_t finger, uint32_t button, float x, float y, float pressure) {
    if (g_touchpad_down) g_touchpad_down(touchpad, finger, button, x, y, pressure);
}

void ldv_input_gamepad_touchpad_motion(uint32_t touchpad, uint32_t finger, uint32_t button, float x, float y, float dx, float dy, float pressure) {
    if (g_touchpad_motion) g_touchpad_motion(touchpad, finger, button, x, y, dx, dy, pressure);
}

void ldv_input_gamepad_touchpad_up(uint32_t touchpad, uint32_t finger, uint32_t button, float x, float y, float pressure) {
    if (g_touchpad_up) g_touchpad_up(touchpad, finger, button, x, y, pressure);
}

void ldv_input_key_down(int scancode, int keycode, int modifiers) {
    if (g_key_down) g_key_down(scancode, keycode, modifiers);
}

void ldv_input_key_up(int scancode, int keycode, int modifiers) {
    if (g_key_up) g_key_up(scancode, keycode, modifiers);
}

void ldv_input_text(const char *text) {
    if (g_text) g_text(text);
}

void ldv_input_focus_lost(void) {}
void ldv_input_focus_gained(void) {}
