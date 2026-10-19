package com.luduvo.client

import android.content.Context
import android.content.res.AssetManager
import android.os.SystemClock
import android.util.Log
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import androidx.lifecycle.LifecycleObserver
import androidx.lifecycle.OnLifecycleEvent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class LuduvoEngine(private val context: Context) : LifecycleObserver, CoroutineScope {

    companion object {
        private const val TAG = "LuduvoEngine"
        private var sLoaded = false
        fun loadLibrary() {
            if (!sLoaded) {
                System.loadLibrary("luduvo")
                sLoaded = true
                Log.i(TAG, "Native library loaded")
            }
        }
    }

    // CoroutineScope implementation
    override val coroutineContext = Dispatchers.Default + Job()

    // Native methods
    external fun nativeInit(configPath: String)
    external fun nativeShutdown()
    external fun nativeTick(dt: Float)
    external fun nativeResize(width: Int, height: Int)

    // Touch input
    external fun nativeTouchDown(timestamp: Long, touchId: Int, fingerId: Int, x: Float, y: Float, pressure: Float)
    external fun nativeTouchMove(timestamp: Long, touchId: Int, fingerId: Int, x: Float, y: Float, dx: Float, dy: Float, pressure: Float)
    external fun nativeTouchUp(timestamp: Long, touchId: Int, fingerId: Int, x: Float, y: Float, pressure: Float)

    // Keyboard input
    external fun nativeKeyDown(scancode: Int, keycode: Int, modifiers: Int)
    external fun nativeKeyUp(scancode: Int, keycode: Int, modifiers: Int)
    external fun nativeTextInput(text: String)

    // Focus
    external fun nativeFocusLost()
    external fun nativeFocusGained()

    // State
    private var _isRunning = false
    private var _surfaceWidth = 0
    private var _surfaceHeight = 0
    private var _lastFrameTime = 0L
    private var _frameCount = 0L
    private var _fps = 0.0f

    val isRunning: Boolean
        get() = _isRunning

    fun start(configPath: String) {
        if (_isRunning) return
        nativeInit(configPath)
        _isRunning = true
        _lastFrameTime = SystemClock.uptimeMillis()
        _frameCount = 0
        launch { gameLoop() }
    }

    fun stop() {
        if (!_isRunning) return
        _isRunning = false
        nativeShutdown()
    }

    fun onSurfaceCreated(holder: SurfaceHolder) {
        // Surface ready - engine will render to it via SDL3
        Log.i(TAG, "Surface created")
    }

    fun onSurfaceChanged(holder: SurfaceHolder, width: Int, height: Int) {
        _surfaceWidth = width
        _surfaceHeight = height
        nativeResize(width, height)
        Log.i(TAG, "Surface changed: ${width}x${height}")
    }

    fun onSurfaceDestroyed(holder: SurfaceHolder) {
        Log.i(TAG, "Surface destroyed")
    }

    fun onTouchEvent(event: MotionEvent): Boolean {
        val action = event.actionMasked
        val pointerIndex = event.actionIndex
        val pointerId = event.getPointerId(pointerIndex)
        val timestamp = SystemClock.uptimeMillis() * 1_000_000 // Convert to nanoseconds

        when (action) {
            MotionEvent.ACTION_DOWN,
            MotionEvent.ACTION_POINTER_DOWN -> {
                val x = event.getX(pointerIndex)
                val y = event.getY(pointerIndex)
                val pressure = event.getPressure(pointerIndex)
                nativeTouchDown(timestamp, pointerId, 0, x, y, pressure)
            }
            MotionEvent.ACTION_UP,
            MotionEvent.ACTION_POINTER_UP,
            MotionEvent.ACTION_CANCEL -> {
                val x = event.getX(pointerIndex)
                val y = event.getY(pointerIndex)
                val pressure = event.getPressure(pointerIndex)
                nativeTouchUp(timestamp, pointerId, 0, x, y, pressure)
            }
            MotionEvent.ACTION_MOVE -> {
                val count = event.pointerCount
                for (i in 0 until count) {
                    val id = event.getPointerId(i)
                    val x = event.getX(i)
                    val y = event.getY(i)
                    val pressure = event.getPressure(i)
                    // Simplified dx/dy - in production use historical positions
                    nativeTouchMove(timestamp, id, 0, x, y, 0f, 0f, pressure)
                }
            }
        }
        return true
    }

    fun onKeyEvent(keyCode: Int, action: Int, event: android.view.KeyEvent?): Boolean {
        val scancode = keyCode // Simplified mapping
        val modifiers = event?.metaState ?: 0
        if (action == android.view.KeyEvent.ACTION_DOWN) {
            nativeKeyDown(scancode, keyCode, modifiers)
        } else if (action == android.view.KeyEvent.ACTION_UP) {
            nativeKeyUp(scancode, keyCode, modifiers)
        }
        return true
    }

    fun onTextInput(text: String) {
        nativeTextInput(text)
    }

    private fun gameLoop() {
        while (_isRunning) {
            val now = SystemClock.uptimeMillis()
            val dt = (now - _lastFrameTime) / 1000.0f
            _lastFrameTime = now

            nativeTick(dt)

            _frameCount++
            if (_frameCount % 60 == 0) {
                _fps = 1000.0f / dt
            }

            // Target 60 FPS ~ 16.67ms
            val frameTime = SystemClock.uptimeMillis() - now
            val sleepTime = maxOf(0, 16 - frameTime)
            if (sleepTime > 0) {
                Thread.sleep(sleepTime.toLong())
            }
        }
    }

    fun getFps(): Float = _fps
}

class LuduvoSurfaceView(context: Context, private val engine: LuduvoEngine) :
    SurfaceView(context), SurfaceHolder.Callback {

    init {
        holder.addCallback(this)
        setFocusable(true)
        setFocusableInTouchMode(true)
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        engine.onSurfaceCreated(holder)
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        engine.onSurfaceChanged(holder, width, height)
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        engine.onSurfaceDestroyed(holder)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        return engine.onTouchEvent(event)
    }

    override fun onKeyDown(keyCode: Int, event: android.view.KeyEvent?): Boolean {
        return engine.onKeyEvent(keyCode, android.view.KeyEvent.ACTION_DOWN, event)
    }

    override fun onKeyUp(keyCode: Int, event: android.view.KeyEvent?): Boolean {
        return engine.onKeyEvent(keyCode, android.view.KeyEvent.ACTION_UP, event)
    }
}