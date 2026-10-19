package com.luduvo.client

import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity

class EditorActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "LuduvoEditor"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Fullscreen immersive mode
        window.decorView.systemUiVisibility = (
            android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            or android.view.View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            or android.view.View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            or android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            or android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            or android.view.View.SYSTEM_UI_FLAG_FULLSCREEN
        )

        // Load editor native library
        System.loadLibrary("luduvo_editor")

        Log.i(TAG, "Luduvo Studio started on Android")

        // TODO: Implement editor UI - for now show placeholder
        setContentView(android.R.layout.activity_main)
    }
}