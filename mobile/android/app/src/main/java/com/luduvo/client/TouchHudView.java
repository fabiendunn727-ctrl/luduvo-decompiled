package com.luduvo.client;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.view.MotionEvent;
import android.view.View;

/**
 * Touch HUD: two virtual sticks and a button cluster.
 *
 * Layout mirrors the iOS client - left stick drives movement, right stick
 * drives the camera, and the action cluster sits above the right stick.
 */
public final class TouchHudView extends View {

    private static final int STICK_MOVE = LuduvoEngine.STICK_MOVE;
    private static final int STICK_LOOK = LuduvoEngine.STICK_LOOK;

    private final TouchHudListener listener;
    private final Paint fill = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint stroke = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint text = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF rect = new RectF();

    private final float density;

    private float stickRadius;
    private float knobRadius;
    private float buttonRadius;
    private float margin;
    private float spacing;

    private final float[] stickCenterX = new float[2];
    private final float[] stickCenterY = new float[2];
    private final float[] stickKnobX = new float[2];
    private final float[] stickKnobY = new float[2];
    private final int[] stickPointer = new int[] { -1, -1 };

    private final int[] buttonId = new int[5];
    private final float[] buttonX = new float[5];
    private final float[] buttonY = new float[5];
    private final int[] buttonPointer = new int[] { -1, -1, -1, -1, -1 };
    private final String[] buttonLabel = { "JUMP", "RUN", "ACT", "BAG", "CHAT" };

    public TouchHudView(Context context, TouchHudListener listener) {
        super(context);
        this.listener = listener;
        setWillNotDraw(false);
        density = context.getResources().getDisplayMetrics().density;

        fill.setStyle(Paint.Style.FILL);
        stroke.setStyle(Paint.Style.STROKE);
        stroke.setStrokeWidth(2f * density);
        text.setColor(Color.WHITE);
        text.setTextAlign(Paint.Align.CENTER);
        text.setTextSize(11f * density);
    }

    @Override
    protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        super.onSizeChanged(w, h, oldw, oldh);

        margin = 20f * density;
        spacing = 12f * density;
        stickRadius = Math.min(w, h) * 0.12f;
        knobRadius = stickRadius * 0.45f;
        buttonRadius = 28f * density;

        stickCenterX[STICK_MOVE] = margin + stickRadius;
        stickCenterY[STICK_MOVE] = h - margin - stickRadius;
        stickCenterX[STICK_LOOK] = w - margin - stickRadius;
        stickCenterY[STICK_LOOK] = h - margin - stickRadius;

        stickKnobX[STICK_MOVE] = stickCenterX[STICK_MOVE];
        stickKnobY[STICK_MOVE] = stickCenterY[STICK_MOVE];
        stickKnobX[STICK_LOOK] = stickCenterX[STICK_LOOK];
        stickKnobY[STICK_LOOK] = stickCenterY[STICK_LOOK];

        // Action cluster sits above the right stick.
        float clusterY = stickCenterY[STICK_LOOK] - stickRadius - margin - buttonRadius;
        buttonX[LuduvoEngine.BUTTON_JUMP] = w - margin - buttonRadius;
        buttonY[LuduvoEngine.BUTTON_JUMP] = clusterY;
        buttonX[LuduvoEngine.BUTTON_SPRINT] = buttonX[LuduvoEngine.BUTTON_JUMP] - 2 * buttonRadius - spacing;
        buttonY[LuduvoEngine.BUTTON_SPRINT] = clusterY;
        buttonX[LuduvoEngine.BUTTON_ACTION] = buttonX[LuduvoEngine.BUTTON_SPRINT] - 2 * buttonRadius - spacing;
        buttonY[LuduvoEngine.BUTTON_ACTION] = clusterY;

        // Inventory and chat live in the top right corner.
        float topY = margin + 36f * density + buttonRadius;
        buttonX[LuduvoEngine.BUTTON_INVENTORY] = w - margin - buttonRadius;
        buttonY[LuduvoEngine.BUTTON_INVENTORY] = topY;
        buttonX[LuduvoEngine.BUTTON_CHAT] = buttonX[LuduvoEngine.BUTTON_INVENTORY] - 2 * buttonRadius - spacing;
        buttonY[LuduvoEngine.BUTTON_CHAT] = topY;

        for (int i = 0; i < buttonId.length; i++) {
            buttonId[i] = i;
        }
    }

    @Override
    protected void onDraw(Canvas canvas) {
        drawStick(canvas, STICK_MOVE);
        drawStick(canvas, STICK_LOOK);
        for (int i = 0; i < buttonId.length; i++) {
            drawButton(canvas, i);
        }
    }

    private void drawStick(Canvas canvas, int which) {
        fill.setColor(Color.argb(90, 124, 77, 255));
        canvas.drawCircle(stickCenterX[which], stickCenterY[which], stickRadius, fill);
        stroke.setColor(Color.argb(200, 124, 77, 255));
        canvas.drawCircle(stickCenterX[which], stickCenterY[which], stickRadius, stroke);

        fill.setColor(Color.argb(230, 124, 77, 255));
        canvas.drawCircle(stickKnobX[which], stickKnobY[which], knobRadius, fill);
    }

    private void drawButton(Canvas canvas, int which) {
        boolean down = buttonPointer[which] >= 0;
        fill.setColor(down ? Color.argb(150, 0, 229, 255) : Color.argb(70, 0, 229, 255));
        canvas.drawCircle(buttonX[which], buttonY[which], buttonRadius, fill);
        stroke.setColor(Color.argb(190, 0, 229, 255));
        canvas.drawCircle(buttonX[which], buttonY[which], buttonRadius, stroke);

        text.setColor(Color.WHITE);
        canvas.drawText(buttonLabel[which], buttonX[which], buttonY[which] + text.getTextSize() * 0.35f, text);
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        final int action = event.getActionMasked();

        switch (action) {
            case MotionEvent.ACTION_DOWN:
            case MotionEvent.ACTION_POINTER_DOWN: {
                int index = event.getActionIndex();
                int pointerId = event.getPointerId(index);
                float x = event.getX(index);
                float y = event.getY(index);
                if (pressButton(pointerId, x, y)) {
                    break;
                }
                int which = stickAt(x, y);
                if (which >= 0) {
                    stickPointer[which] = pointerId;
                    updateStick(which, x, y);
                }
                break;
            }
            case MotionEvent.ACTION_MOVE: {
                for (int i = 0; i < event.getPointerCount(); i++) {
                    int pointerId = event.getPointerId(i);
                    for (int which = 0; which < 2; which++) {
                        if (stickPointer[which] == pointerId) {
                            updateStick(which, event.getX(i), event.getY(i));
                        }
                    }
                }
                break;
            }
            case MotionEvent.ACTION_UP:
            case MotionEvent.ACTION_POINTER_UP: {
                int index = event.getActionIndex();
                int pointerId = event.getPointerId(index);
                for (int which = 0; which < 2; which++) {
                    if (stickPointer[which] == pointerId) {
                        stickPointer[which] = -1;
                        resetStick(which);
                    }
                }
                for (int i = 0; i < buttonId.length; i++) {
                    if (buttonPointer[i] == pointerId) {
                        buttonPointer[i] = -1;
                        listener.onButton(i, false);
                    }
                }
                break;
            }
            case MotionEvent.ACTION_CANCEL: {
                for (int which = 0; which < 2; which++) {
                    if (stickPointer[which] >= 0) {
                        stickPointer[which] = -1;
                        resetStick(which);
                    }
                }
                for (int i = 0; i < buttonId.length; i++) {
                    if (buttonPointer[i] >= 0) {
                        buttonPointer[i] = -1;
                        listener.onButton(i, false);
                    }
                }
                break;
            }
            default:
                break;
        }
        return true;
    }

    private boolean pressButton(int pointerId, float x, float y) {
        for (int i = 0; i < buttonId.length; i++) {
            float dx = x - buttonX[i];
            float dy = y - buttonY[i];
            if (dx * dx + dy * dy <= buttonRadius * buttonRadius * 1.6f) {
                buttonPointer[i] = pointerId;
                listener.onButton(i, true);
                invalidate();
                return true;
            }
        }
        return false;
    }

    private int stickAt(float x, float y) {
        for (int which = 0; which < 2; which++) {
            if (stickPointer[which] >= 0) {
                continue;
            }
            float dx = x - stickCenterX[which];
            float dy = y - stickCenterY[which];
            // Generous hit area so the stick can be grabbed anywhere in its zone.
            if (dx * dx + dy * dy <= stickRadius * stickRadius * 2.4f) {
                return which;
            }
        }
        return -1;
    }

    private void updateStick(int which, float x, float y) {
        float dx = x - stickCenterX[which];
        float dy = y - stickCenterY[which];
        float distance = (float) Math.sqrt(dx * dx + dy * dy);
        float clamped = Math.min(distance, stickRadius);
        float nx = distance > 0f ? dx / distance : 0f;
        float ny = distance > 0f ? dy / distance : 0f;

        stickKnobX[which] = stickCenterX[which] + nx * clamped;
        stickKnobY[which] = stickCenterY[which] + ny * clamped;

        listener.onStick(which, nx * clamped / stickRadius, ny * clamped / stickRadius);
        invalidate();
    }

    private void resetStick(int which) {
        stickKnobX[which] = stickCenterX[which];
        stickKnobY[which] = stickCenterY[which];
        listener.onStick(which, 0f, 0f);
        invalidate();
    }
}
