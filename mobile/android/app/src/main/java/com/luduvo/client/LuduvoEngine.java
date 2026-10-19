package com.luduvo.client;

import android.util.Log;

/**
 * Bridge between the Android client shell and the Luduvo engine.
 *
 * The engine ships as {@code libluduvo.so}. When that library is not present
 * the client still runs: {@link #hasNativeEngine()} reports false and the
 * shell falls back to its own renderer and input model, so the touch HUD,
 * deep links and lifecycle stay testable on a device without the engine.
 */
public final class LuduvoEngine {

    public static final String TAG = "LuduvoEngine";

    /** Left stick drives movement. */
    public static final int STICK_MOVE = 0;
    /** Right stick drives the camera. */
    public static final int STICK_LOOK = 1;

    public static final int BUTTON_JUMP = 0;
    public static final int BUTTON_SPRINT = 1;
    public static final int BUTTON_ACTION = 2;
    public static final int BUTTON_INVENTORY = 3;
    public static final int BUTTON_CHAT = 4;

    public static final int BUTTON_COUNT = 5;

    private static boolean sLibraryLoaded;
    private static boolean sLibraryMissing;

    private boolean running;
    private long lastFrameTime;
    private long frameCount;
    private float fps;

    // Fallback world state, used when the native engine is unavailable.
    private float playerX;
    private float playerZ;
    private float yaw;
    private float pitch;
    private final float[] stick = new float[2 * 2];
    private final boolean[] button = new boolean[BUTTON_COUNT];
    private int surfaceWidth;
    private int surfaceHeight;

    /**
     * Loads the native engine library. Safe to call more than once and safe
     * to call when the library is missing.
     */
    public static synchronized void loadLibrary() {
        if (sLibraryLoaded || sLibraryMissing) {
            return;
        }
        try {
            System.loadLibrary("luduvo");
            sLibraryLoaded = true;
        } catch (UnsatisfiedLinkError e) {
            sLibraryMissing = true;
            Log.i(TAG, "libluduvo.so not available, using the built-in fallback renderer");
        }
    }

    /** True when the native engine library is loaded and callable. */
    public static boolean hasNativeEngine() {
        return sLibraryLoaded;
    }

    public boolean isRunning() {
        return running;
    }

    public float getFps() {
        return fps;
    }

    public int getSurfaceWidth() {
        return surfaceWidth;
    }

    public int getSurfaceHeight() {
        return surfaceHeight;
    }

    /**
     * Starts the engine with the given join configuration file.
     *
     * @param configPath absolute path of the join configuration, may be null
     */
    public void start(String configPath) {
        if (running) {
            return;
        }
        if (hasNativeEngine()) {
            try {
                nativeInit(configPath);
            } catch (UnsatisfiedLinkError e) {
                markLibraryMissing();
            }
        }
        running = true;
        lastFrameTime = System.nanoTime();
        frameCount = 0;
        fps = 0f;
    }

    public void stop() {
        if (!running) {
            return;
        }
        running = false;
        if (hasNativeEngine()) {
            try {
                nativeShutdown();
            } catch (UnsatisfiedLinkError e) {
                markLibraryMissing();
            }
        }
    }

    public void resize(int width, int height) {
        surfaceWidth = width;
        surfaceHeight = height;
        if (hasNativeEngine()) {
            try {
                nativeResize(width, height);
            } catch (UnsatisfiedLinkError e) {
                markLibraryMissing();
            }
        }
    }

    /** Advances the engine by {@code dt} seconds. */
    public void tick(float dt) {
        if (!running) {
            return;
        }
        if (hasNativeEngine()) {
            try {
                nativeTick(dt);
            } catch (UnsatisfiedLinkError e) {
                markLibraryMissing();
            }
        }

        long now = System.nanoTime();
        lastFrameTime = now;
        frameCount++;
        if ((frameCount % 30) == 0) {
            fps = 1f / Math.max(dt, 0.0001f);
        }

        // Fallback integration: move the marker with the left stick, turn the
        // camera with the right stick.
        float moveX = stick[STICK_MOVE * 2];
        float moveY = stick[STICK_MOVE * 2 + 1];
        float speed = button[BUTTON_SPRINT] ? 12f : 6f;
        playerX += moveX * speed * dt;
        playerZ += -moveY * speed * dt;
        yaw += stick[STICK_LOOK * 2] * 120f * dt;
        pitch += stick[STICK_LOOK * 2 + 1] * 90f * dt;
        if (pitch > 80f) {
            pitch = 80f;
        }
        if (pitch < -80f) {
            pitch = -80f;
        }
    }

    /** Reports a virtual stick position, components in the range -1..1. */
    public void touchStick(int which, float x, float y) {
        if (which != STICK_MOVE && which != STICK_LOOK) {
            return;
        }
        stick[which * 2] = x;
        stick[which * 2 + 1] = y;
        if (hasNativeEngine()) {
            try {
                nativeTouchStick(which, x, y);
            } catch (UnsatisfiedLinkError e) {
                markLibraryMissing();
            }
        }
    }

    /** Reports a virtual button press or release. */
    public void touchButton(int which, boolean pressed) {
        if (which < 0 || which >= BUTTON_COUNT) {
            return;
        }
        button[which] = pressed;
        if (hasNativeEngine()) {
            try {
                nativeTouchButton(which, pressed);
            } catch (UnsatisfiedLinkError e) {
                markLibraryMissing();
            }
        }
    }

    public boolean isButtonDown(int which) {
        return which >= 0 && which < BUTTON_COUNT && button[which];
    }

    public void gamepadDpad(float x, float y) {
        if (hasNativeEngine()) {
            try {
                nativeGamepadDpad(x, y);
            } catch (UnsatisfiedLinkError e) {
                markLibraryMissing();
            }
        }
    }

    public void gamepadButton(int which, float value, boolean pressed) {
        if (hasNativeEngine()) {
            try {
                nativeGamepadButton(which, value, pressed);
            } catch (UnsatisfiedLinkError e) {
                markLibraryMissing();
            }
        }
    }

    public void gamepadTrigger(int which, float value, boolean pressed) {
        if (hasNativeEngine()) {
            try {
                nativeGamepadTrigger(which, value, pressed);
            } catch (UnsatisfiedLinkError e) {
                markLibraryMissing();
            }
        }
    }

    public float getPlayerX() {
        return playerX;
    }

    public float getPlayerZ() {
        return playerZ;
    }

    public float getYaw() {
        return yaw;
    }

    public float getPitch() {
        return pitch;
    }

    private static synchronized void markLibraryMissing() {
        sLibraryLoaded = false;
        sLibraryMissing = true;
    }

    private static native void nativeInit(String configPath);

    private static native void nativeShutdown();

    private static native void nativeTick(float dt);

    private static native void nativeResize(int width, int height);

    private static native void nativeTouchStick(int which, float x, float y);

    private static native void nativeTouchButton(int which, boolean pressed);

    private static native void nativeGamepadDpad(float x, float y);

    private static native void nativeGamepadButton(int which, float value, boolean pressed);

    private static native void nativeGamepadTrigger(int which, float value, boolean pressed);
}
