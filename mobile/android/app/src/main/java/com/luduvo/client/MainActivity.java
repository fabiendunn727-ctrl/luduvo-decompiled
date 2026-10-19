package com.luduvo.client;

import android.content.Context;
import android.os.Bundle;
import android.os.Environment;
import android.util.Log;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.FrameLayout;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;

/**
 * Luduvo client entry point.
 *
 * Hosts the renderer, the touch HUD and handles the join deep links
 * ({@code luduvo://}, {@code buildoverse://} and
 * {@code https://buildoverse.com/join/}).
 */
public final class MainActivity extends android.app.Activity {

    private static final String TAG = "LuduvoActivity";
    private static final String DEFAULT_HOST = "194.163.173.138";
    private static final int DEFAULT_PORT = 55000;

    private LuduvoEngine engine;
    private LuduvoSurfaceView surfaceView;
    private TouchHudView hudView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Window window = getWindow();
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        window.setStatusBarColor(0x00000000);
        window.setNavigationBarColor(0x00000000);
        window.getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);

        LuduvoEngine.loadLibrary();
        engine = new LuduvoEngine();

        surfaceView = new LuduvoSurfaceView(this, engine);
        hudView = new TouchHudView(this, new HudListener(engine));

        FrameLayout layout = new FrameLayout(this);
        layout.addView(surfaceView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
        layout.addView(hudView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
        setContentView(layout);

        handleIntent(getIntent());
    }

    @Override
    protected void onNewIntent(android.content.Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleIntent(intent);
    }

    @Override
    protected void onResume() {
        super.onResume();
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    }

    @Override
    protected void onPause() {
        getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        if (engine != null) {
            engine.stop();
        }
        super.onDestroy();
    }

    /**
     * Forwards HUD input to the engine. A static nested class: the dexer used
     * by the plain-SDK build cannot handle anonymous inner classes.
     */
    private static final class HudListener implements TouchHudListener {

        private final LuduvoEngine engine;

        HudListener(LuduvoEngine engine) {
            this.engine = engine;
        }

        @Override
        public void onStick(int which, float x, float y) {
            engine.touchStick(which, x, y);
        }

        @Override
        public void onButton(int which, boolean pressed) {
            engine.touchButton(which, pressed);
        }
    }

    @Override
    public boolean onGenericMotionEvent(MotionEvent event) {
        if (event.getAction() == MotionEvent.ACTION_MOVE) {
            if (handleGamepadAxes(event) || handleGamepadButtons(event)) {
                return true;
            }
        }
        return super.onGenericMotionEvent(event);
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        switch (keyCode) {
            case KeyEvent.KEYCODE_DPAD_UP:
                engine.touchButton(LuduvoEngine.BUTTON_JUMP, true);
                return true;
            case KeyEvent.KEYCODE_DPAD_DOWN:
                engine.touchButton(LuduvoEngine.BUTTON_ACTION, true);
                return true;
            case KeyEvent.KEYCODE_DPAD_LEFT:
                engine.touchButton(LuduvoEngine.BUTTON_SPRINT, true);
                return true;
            case KeyEvent.KEYCODE_DPAD_RIGHT:
                engine.touchButton(LuduvoEngine.BUTTON_INVENTORY, true);
                return true;
            case KeyEvent.KEYCODE_BUTTON_A:
                engine.touchButton(LuduvoEngine.BUTTON_JUMP, true);
                return true;
            case KeyEvent.KEYCODE_BUTTON_B:
                engine.touchButton(LuduvoEngine.BUTTON_ACTION, true);
                return true;
            case KeyEvent.KEYCODE_BUTTON_X:
                engine.touchButton(LuduvoEngine.BUTTON_SPRINT, true);
                return true;
            case KeyEvent.KEYCODE_BUTTON_Y:
                engine.touchButton(LuduvoEngine.BUTTON_INVENTORY, true);
                return true;
            default:
                break;
        }
        return super.onKeyDown(keyCode, event);
    }

    @Override
    public boolean onKeyUp(int keyCode, KeyEvent event) {
        switch (keyCode) {
            case KeyEvent.KEYCODE_DPAD_UP:
            case KeyEvent.KEYCODE_BUTTON_A:
                engine.touchButton(LuduvoEngine.BUTTON_JUMP, false);
                return true;
            case KeyEvent.KEYCODE_DPAD_DOWN:
            case KeyEvent.KEYCODE_BUTTON_B:
                engine.touchButton(LuduvoEngine.BUTTON_ACTION, false);
                return true;
            case KeyEvent.KEYCODE_DPAD_LEFT:
            case KeyEvent.KEYCODE_BUTTON_X:
                engine.touchButton(LuduvoEngine.BUTTON_SPRINT, false);
                return true;
            case KeyEvent.KEYCODE_DPAD_RIGHT:
            case KeyEvent.KEYCODE_BUTTON_Y:
                engine.touchButton(LuduvoEngine.BUTTON_INVENTORY, false);
                return true;
            default:
                break;
        }
        return super.onKeyUp(keyCode, event);
    }

    private boolean handleGamepadAxes(MotionEvent event) {
        boolean handled = false;
        float lx = event.getAxisValue(MotionEvent.AXIS_X);
        float ly = event.getAxisValue(MotionEvent.AXIS_Y);
        if (Math.abs(lx) > 0.15f || Math.abs(ly) > 0.15f) {
            engine.touchStick(LuduvoEngine.STICK_MOVE, lx, -ly);
            handled = true;
        }
        float rx = event.getAxisValue(MotionEvent.AXIS_Z);
        float ry = event.getAxisValue(MotionEvent.AXIS_RZ);
        if (Math.abs(rx) > 0.15f || Math.abs(ry) > 0.15f) {
            engine.touchStick(LuduvoEngine.STICK_LOOK, rx, -ry);
            handled = true;
        }
        float dpadX = event.getAxisValue(MotionEvent.AXIS_HAT_X);
        float dpadY = event.getAxisValue(MotionEvent.AXIS_HAT_Y);
        if (dpadX != 0f || dpadY != 0f) {
            engine.gamepadDpad(dpadX, dpadY);
            handled = true;
        }
        return handled;
    }

    private boolean handleGamepadButtons(MotionEvent event) {
        boolean handled = false;
        int states = event.getButtonState();
        handled |= setGamepadButton(states, KeyEvent.KEYCODE_BUTTON_A, LuduvoEngine.BUTTON_JUMP);
        handled |= setGamepadButton(states, KeyEvent.KEYCODE_BUTTON_B, LuduvoEngine.BUTTON_ACTION);
        handled |= setGamepadButton(states, KeyEvent.KEYCODE_BUTTON_X, LuduvoEngine.BUTTON_SPRINT);
        handled |= setGamepadButton(states, KeyEvent.KEYCODE_BUTTON_Y, LuduvoEngine.BUTTON_INVENTORY);
        handled |= setGamepadTrigger(states, KeyEvent.KEYCODE_BUTTON_L1, 0);
        handled |= setGamepadTrigger(states, KeyEvent.KEYCODE_BUTTON_R1, 1);
        return handled;
    }

    private boolean setGamepadButton(int states, int key, int engineButton) {
        boolean pressed = (states & (1 << key)) != 0;
        engine.gamepadButton(engineButton, pressed ? 1f : 0f, pressed);
        engine.touchButton(engineButton, pressed);
        return true;
    }

    private boolean setGamepadTrigger(int states, int key, int engineTrigger) {
        boolean pressed = (states & (1 << key)) != 0;
        engine.gamepadTrigger(engineTrigger, pressed ? 1f : 0f, pressed);
        return true;
    }

    private void handleIntent(android.content.Intent intent) {
        if (intent == null || intent.getData() == null) {
            return;
        }
        String url = intent.getData().toString();
        String scheme = intent.getData().getScheme();
        if (!"luduvo".equals(scheme) && !"buildoverse".equals(scheme)
                && !"https".equals(scheme) && !"http".equals(scheme)) {
            return;
        }

        String token = "";
        String host = DEFAULT_HOST;
        int port = DEFAULT_PORT;
        String pubkey = "";

        try {
            URI uri = new URI(url);
            String path = uri.getPath();
            if (path != null && path.startsWith("/")) {
                path = path.substring(1);
            }
            String[] parts = path == null ? new String[0] : path.split("/");
            if (parts.length > 0 && !parts[0].isEmpty()) {
                token = parts[0];
            }
            if (parts.length > 1 && !parts[1].isEmpty()) {
                host = parts[1];
            }
            if (parts.length > 2 && !parts[2].isEmpty()) {
                try {
                    port = Integer.parseInt(parts[2]);
                } catch (NumberFormatException ignored) {
                    port = DEFAULT_PORT;
                }
            }
            if (parts.length > 3) {
                pubkey = parts[3];
            }
            if (uri.getHost() != null && !uri.getHost().isEmpty()) {
                host = uri.getHost();
            }
            if (uri.getPort() > 0) {
                port = uri.getPort();
            }
        } catch (URISyntaxException e) {
            Log.w(TAG, "unparseable deep link: " + url, e);
            return;
        }

        File config = writeConfig(token, host, port, pubkey);
        if (config == null) {
            return;
        }
        Log.i(TAG, "join " + host + ":" + port);
        engine.start(config.getAbsolutePath());
    }

    private File writeConfig(String token, String host, int port, String pubkey) {
        File dir = getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS);
        if (dir == null) {
            dir = getFilesDir();
        }
        File file = new File(dir, "luduvo_join.json");
        String json = "{\"token\":\"" + escape(token) + "\",\"host\":\"" + escape(host)
                + "\",\"port\":" + port + ",\"pubkey\":\"" + escape(pubkey) + "\"}";
        FileOutputStream out = null;
        try {
            out = new FileOutputStream(file);
            out.write(json.getBytes("UTF-8"));
            out.flush();
        } catch (IOException e) {
            Log.w(TAG, "could not write join config", e);
            return null;
        } finally {
            if (out != null) {
                try {
                    out.close();
                } catch (IOException ignored) {
                    // nothing useful to do here
                }
            }
        }
        return file;
    }

    private static String escape(String value) {
        if (value == null) {
            return "";
        }
        return value.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
