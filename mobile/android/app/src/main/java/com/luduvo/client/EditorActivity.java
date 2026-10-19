package com.luduvo.client;

import android.os.Bundle;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.FrameLayout;

/**
 * Luduvo studio (editor) entry point. Shares the renderer and engine bridge
 * with the client; the editor surface is driven by the same touch HUD.
 */
public final class EditorActivity extends android.app.Activity {

    private LuduvoEngine engine;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Window window = getWindow();
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        window.getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);

        LuduvoEngine.loadLibrary();
        engine = new LuduvoEngine();

        FrameLayout layout = new FrameLayout(this);
        layout.addView(new LuduvoSurfaceView(this, engine), new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
        setContentView(layout);
    }

    @Override
    protected void onDestroy() {
        if (engine != null) {
            engine.stop();
        }
        super.onDestroy();
    }
}
