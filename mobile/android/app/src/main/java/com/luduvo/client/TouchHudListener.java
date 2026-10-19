package com.luduvo.client;

/**
 * Receives virtual control input from {@link TouchHudView}.
 */
public interface TouchHudListener {

    /**
     * A virtual stick moved.
     *
     * @param which {@link LuduvoEngine#STICK_MOVE} or {@link LuduvoEngine#STICK_LOOK}
     * @param x     horizontal component, -1..1
     * @param y     vertical component, -1..1
     */
    void onStick(int which, float x, float y);

    /**
     * A virtual button was pressed or released.
     */
    void onButton(int which, boolean pressed);
}
