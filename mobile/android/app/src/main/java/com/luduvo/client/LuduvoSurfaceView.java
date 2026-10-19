package com.luduvo.client;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Shader;
import android.util.Log;
import android.view.SurfaceHolder;
import android.view.SurfaceView;

/**
 * Renders the client view.
 *
 * The surface is driven by its own thread so the frame rate is independent of
 * the UI thread. When the native engine is present it owns the pixels; the
 * fallback renderer below draws a simple world so the shell is still usable
 * (and testable) without {@code libluduvo.so}.
 */
public final class LuduvoSurfaceView extends SurfaceView implements SurfaceHolder.Callback {

    private static final String TAG = "LuduvoSurfaceView";
    private static final long FRAME_NS = 16_666_667L;

    private final LuduvoEngine engine;
    private Thread renderThread;
    private volatile boolean running;

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint hudText = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint gridPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint markerPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    public LuduvoSurfaceView(Context context, LuduvoEngine engine) {
        super(context);
        this.engine = engine;
        getHolder().addCallback(this);
        setFocusable(true);
        setFocusableInTouchMode(true);

        hudText.setColor(Color.WHITE);
        hudText.setTextSize(13f * context.getResources().getDisplayMetrics().density);
        gridPaint.setColor(Color.argb(70, 255, 255, 255));
        gridPaint.setStrokeWidth(1f * context.getResources().getDisplayMetrics().density);
        markerPaint.setColor(Color.rgb(124, 77, 255));
    }

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        start();
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        engine.resize(width, height);
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        stop();
    }

    private synchronized void start() {
        if (running) {
            return;
        }
        running = true;
        renderThread = new Thread(new RenderRunnable(this), "LuduvoRender");
        renderThread.start();
    }

    private synchronized void stop() {
        running = false;
        Thread t = renderThread;
        renderThread = null;
        if (t != null) {
            try {
                t.join(1000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }

    void renderLoop() {
        long previous = System.nanoTime();
        while (running) {
            long now = System.nanoTime();
            float dt = (now - previous) / 1_000_000_000f;
            previous = now;
            if (dt > 0.25f) {
                dt = 0.25f;
            }

            engine.tick(dt);
            drawFrame();

            long sleep = FRAME_NS - (System.nanoTime() - now);
            if (sleep > 0) {
                try {
                    Thread.sleep(sleep / 1_000_000L, (int) (sleep % 1_000_000L));
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    return;
                }
            }
        }
    }

    /**
     * Render loop body. Kept in a static nested class: the dexer used by the
     * plain-SDK build chokes on anonymous inner classes.
     */
    private static final class RenderRunnable implements Runnable {

        private final LuduvoSurfaceView view;

        RenderRunnable(LuduvoSurfaceView view) {
            this.view = view;
        }

        @Override
        public void run() {
            view.renderLoop();
        }
    }

    private void drawFrame() {
        SurfaceHolder holder = getHolder();
        Canvas canvas = null;
        try {
            canvas = holder.lockCanvas();
            if (canvas == null) {
                return;
            }
            renderScene(canvas);
        } catch (Exception e) {
            Log.w(TAG, "frame failed", e);
        } finally {
            if (canvas != null) {
                holder.unlockCanvasAndPost(canvas);
            }
        }
    }

    private void renderScene(Canvas canvas) {
        final int w = canvas.getWidth();
        final int h = canvas.getHeight();
        if (w <= 0 || h <= 0) {
            return;
        }
        final float horizon = h * 0.45f;

        paint.setShader(new LinearGradient(0, 0, 0, horizon,
                new int[] { Color.rgb(18, 20, 46), Color.rgb(72, 44, 120) },
                null, Shader.TileMode.CLAMP));
        canvas.drawRect(0, 0, w, horizon, paint);
        paint.setShader(null);

        paint.setColor(Color.rgb(24, 26, 32));
        canvas.drawRect(0, horizon, w, h, paint);

        // Perspective floor grid.
        float cx = w * 0.5f + (float) Math.sin(Math.toRadians(engine.getYaw())) * w * 0.35f;
        for (int i = 1; i <= 12; i++) {
            float t = i / 12f;
            float y = horizon + (h - horizon) * t * t;
            canvas.drawLine(0, y, w, y, gridPaint);
        }
        for (int i = -6; i <= 6; i++) {
            float bottomX = cx + i * (w / 6f);
            float topX = cx + i * (w / 40f);
            canvas.drawLine(bottomX, h, topX, horizon, gridPaint);
        }

        // Player marker.
        float mx = w * 0.5f - (float) Math.sin(Math.toRadians(engine.getYaw())) * w * 0.12f;
        float my = horizon + (h - horizon) * 0.35f;
        canvas.drawCircle(mx, my, 18f, markerPaint);
        paint.setColor(Color.WHITE);
        canvas.drawCircle(mx, my, 6f, paint);

        // HUD line.
        String status = LuduvoEngine.hasNativeEngine() ? "engine: native" : "engine: fallback";
        String text = String.format(java.util.Locale.US,
                "Luduvo  %.0f fps  x=%.1f z=%.1f yaw=%.0f  %s",
                engine.getFps(), engine.getPlayerX(), engine.getPlayerZ(), engine.getYaw(), status);
        canvas.drawText(text, 16f, 28f, hudText);
    }
}
