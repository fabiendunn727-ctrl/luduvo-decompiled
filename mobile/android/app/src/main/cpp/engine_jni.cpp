// Luduvo Engine JNI Bridge — Android
// Connects SDL3 touch/input events to the decompiled engine's input system
#include <jni.h>
#include <android/native_activity.h>
#include <android/log.h>
#include <SDL3/SDL.h>
#include <memory>

#define LOG_TAG "LuduvoEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Forward declarations from engine (recovered signatures)
extern "C" {
    // Engine lifecycle
    int  ldv_engine_init(const char* config_path);
    void ldv_engine_shutdown();
    void ldv_engine_tick(float dt);
    void ldv_engine_resize(int width, int height);

    // Input injection (SDL_EVENT_FINGER_* compatible)
    void ldv_input_finger_down(uint64_t timestamp, int touch_id, int finger_id, float x, float y, float pressure);
    void ldv_input_finger_motion(uint64_t timestamp, int touch_id, int finger_id, float x, float y, float dx, float dy, float pressure);
    void ldv_input_finger_up(uint64_t timestamp, int touch_id, int finger_id, float x, float y, float pressure);

    // Gamepad touchpad
    void ldv_input_gamepad_touchpad_down(uint64_t timestamp, int touchpad, int finger, float x, float y, float pressure);
    void ldv_input_gamepad_touchpad_motion(uint64_t timestamp, int touchpad, int finger, float x, float y, float pressure);
    void ldv_input_gamepad_touchpad_up(uint64_t timestamp, int touchpad, int finger, float x, float y, float pressure);

    // Keyboard
    void ldv_input_key_down(int scancode, int keycode, int modifiers);
    void ldv_input_key_up(int scancode, int keycode, int modifiers);
    void ldv_input_text(const char* text);

    // Window focus
    void ldv_input_focus_lost();
    void ldv_input_focus_gained();
}

// Global state
static JavaVM* g_jvm = nullptr;
static jobject g_activity = nullptr;
static std::unique_ptr<SDL_Window, void(*)(SDL_Window*)> g_window(nullptr, SDL_DestroyWindow);
static bool g_engine_running = false;
static uint64_t g_last_frame_ns = 0;

// JNI helper: get JNIEnv for current thread
static JNIEnv* get_jni_env() {
    JNIEnv* env = nullptr;
    if (g_jvm->GetEnv((void**)&env, JNI_VERSION_1_6) != JNI_OK) {
        if (g_jvm->AttachCurrentThread(&env, nullptr) != JNI_OK) {
            return nullptr;
        }
    }
    return env;
}

// Touch event conversion: Android MotionEvent -> engine finger event
static void process_touch_event(JNIEnv* env, jobject event, int action) {
    // action: 0=DOWN, 1=UP, 2=MOVE, 3=CANCEL, 5=POINTER_DOWN, 6=POINTER_UP
    jclass motionEventClass = env->GetObjectClass(event);
    jmethodID getPointerCount = env->GetMethodID(motionEventClass, "getPointerCount", "()I");
    jmethodID getPointerId = env->GetMethodID(motionEventClass, "getPointerId", "(I)I");
    jmethodID getX = env->GetMethodID(motionEventClass, "getX", "(I)F");
    jmethodID getY = env->GetMethodID(motionEventClass, "getY", "(I)F");
    jmethodID getPressure = env->GetMethodID(motionEventClass, "getPressure", "(I)F");
    jmethodID getEventTime = env->GetMethodID(motionEventClass, "getEventTime", "()J");
    jmethodID getActionIndex = env->GetMethodID(motionEventClass, "getActionIndex", "()I");

    int count = env->CallIntMethod(event, getPointerCount);
    int actionIndex = env->CallIntMethod(event, getActionIndex);
    uint64_t timestamp = env->CallLongMethod(event, getEventTime); // ms

    for (int i = 0; i < count; ++i) {
        int pointerId = env->CallIntMethod(event, getPointerId, i);
        float x = env->CallFloatMethod(event, getX, i);
        float y = env->CallFloatMethod(event, getY, i);
        float pressure = env->CallFloatMethod(event, getPressure, i);

        if (action == 0 || action == 5) { // DOWN or POINTER_DOWN
            ldv_input_finger_down(timestamp * 1000000ULL, pointerId, 0, x, y, pressure);
        } else if (action == 1 || action == 6) { // UP or POINTER_UP
            ldv_input_finger_up(timestamp * 1000000ULL, pointerId, 0, x, y, pressure);
        } else if (action == 2) { // MOVE
            // For MOVE we need historical positions for dx/dy - simplified
            static thread_local float lastX[16] = {0};
            static thread_local float lastY[16] = {0};
            float dx = x - lastX[pointerId % 16];
            float dy = y - lastY[pointerId % 16];
            lastX[pointerId % 16] = x;
            lastY[pointerId % 16] = y;
            ldv_input_finger_motion(timestamp * 1000000ULL, pointerId, 0, x, y, dx, dy, pressure);
        }
    }
}

// ---- JNI Exports ----

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* reserved) {
    g_jvm = vm;
    LOGI("JNI_OnLoad: Luduvo engine loaded");
    return JNI_VERSION_1_6;
}

extern "C" JNIEXPORT void JNICALL JNI_OnUnload(JavaVM* vm, void* reserved) {
    if (g_engine_running) {
        ldv_engine_shutdown();
        g_engine_running = false;
    }
    g_jvm = nullptr;
    LOGI("JNI_OnUnload: Luduvo engine unloaded");
}

extern "C" JNIEXPORT void JNICALL
Java_com_luduvo_client_LuduvoEngine_nativeInit(JNIEnv* env, jobject thiz, jstring configPath) {
    if (g_engine_running) {
        LOGI("Engine already running");
        return;
    }

    const char* path = env->GetStringUTFChars(configPath, nullptr);
    int result = ldv_engine_init(path);
    env->ReleaseStringUTFChars(configPath, path);

    if (result == 0) {
        g_engine_running = true;
        g_last_frame_ns = 0;
        LOGI("Engine initialized successfully");
    } else {
        LOGE("Engine init failed: %d", result);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_luduvo_client_LuduvoEngine_nativeShutdown(JNIEnv* env, jobject thiz) {
    if (g_engine_running) {
        ldv_engine_shutdown();
        g_engine_running = false;
        LOGI("Engine shut down");
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_luduvo_client_LuduvoEngine_nativeTick(JNIEnv* env, jobject thiz, jfloat dt) {
    if (g_engine_running) {
        ldv_engine_tick(dt);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_luduvo_client_LuduvoEngine_nativeResize(JNIEnv* env, jobject thiz, jint width, jint height) {
    if (g_engine_running) {
        ldv_engine_resize(width, height);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_luduvo_client_LuduvoEngine_nativeTouchDown(JNIEnv* env, jobject thiz,
                                                    jlong timestamp, jint touchId, jint fingerId,
                                                    jfloat x, jfloat y, jfloat pressure) {
    if (g_engine_running) {
        ldv_input_finger_down(timestamp, touchId, fingerId, x, y, pressure);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_luduvo_client_LuduvoEngine_nativeTouchMove(JNIEnv* env, jobject thiz,
                                                    jlong timestamp, jint touchId, jint fingerId,
                                                    jfloat x, jfloat y, jfloat dx, jfloat dy, jfloat pressure) {
    if (g_engine_running) {
        ldv_input_finger_motion(timestamp, touchId, fingerId, x, y, dx, dy, pressure);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_luduvo_client_LuduvoEngine_nativeTouchUp(JNIEnv* env, jobject thiz,
                                                  jlong timestamp, jint touchId, jint fingerId,
                                                  jfloat x, jfloat y, jfloat pressure) {
    if (g_engine_running) {
        ldv_input_finger_up(timestamp, touchId, fingerId, x, y, pressure);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_luduvo_client_LuduvoEngine_nativeKeyDown(JNIEnv* env, jobject thiz,
                                                  jint scancode, jint keycode, jint modifiers) {
    if (g_engine_running) {
        ldv_input_key_down(scancode, keycode, modifiers);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_luduvo_client_LuduvoEngine_nativeKeyUp(JNIEnv* env, jobject thiz,
                                                jint scancode, jint keycode, jint modifiers) {
    if (g_engine_running) {
        ldv_input_key_up(scancode, keycode, modifiers);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_luduvo_client_LuduvoEngine_nativeTextInput(JNIEnv* env, jobject thiz, jstring text) {
    if (g_engine_running) {
        const char* str = env->GetStringUTFChars(text, nullptr);
        ldv_input_text(str);
        env->ReleaseStringUTFChars(text, str);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_luduvo_client_LuduvoEngine_nativeFocusLost(JNIEnv* env, jobject thiz) {
    if (g_engine_running) {
        ldv_input_focus_lost();
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_luduvo_client_LuduvoEngine_nativeFocusGained(JNIEnv* env, jobject thiz) {
    if (g_engine_running) {
        ldv_input_focus_gained();
    }
}

// ---- Native Activity glue (for GameActivity) ----
extern "C" void ANativeActivity_onCreate(ANativeActivity* activity, void* savedState, size_t savedStateSize) {
    LOGI("ANativeActivity_onCreate");
    activity->callbacks->onStart = [](ANativeActivity* act) {
        LOGI("onStart");
        JNIEnv* env = get_jni_env();
        if (env && act->clazz) {
            env->CallVoidMethod(act->clazz, env->GetMethodID(env->GetObjectClass(act->clazz), "onNativeStart", "()V"));
        }
    };
    activity->callbacks->onResume = [](ANativeActivity* act) {
        LOGI("onResume");
    };
    activity->callbacks->onPause = [](ANativeActivity* act) {
        LOGI("onPause");
    };
    activity->callbacks->onStop = [](ANativeActivity* act) {
        LOGI("onStop");
    };
    activity->callbacks->onDestroy = [](ANativeActivity* act) {
        LOGI("onDestroy");
        if (g_engine_running) {
            ldv_engine_shutdown();
            g_engine_running = false;
        }
    };
    activity->callbacks->onWindowFocusChanged = [](ANativeActivity* act, int focused) {
        LOGI("onWindowFocusChanged: %d", focused);
        if (focused) ldv_input_focus_gained(); else ldv_input_focus_lost();
    };
    activity->callbacks->onInputQueueCreated = [](ANativeActivity* act, AInputQueue* queue) {
        LOGI("onInputQueueCreated");
    };
    activity->callbacks->onInputQueueDestroyed = [](ANativeActivity* act, AInputQueue* queue) {
        LOGI("onInputQueueDestroyed");
    };
    activity->callbacks->onConfigurationChanged = [](ANativeActivity* act) {
        LOGI("onConfigurationChanged");
    };
    activity->callbacks->onLowMemory = [](ANativeActivity* act) {
        LOGI("onLowMemory");
    };
}