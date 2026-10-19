package com.luduvo.client

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.util.Log
import android.view.Window
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.widget.FrameLayout
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleObserver
import androidx.lifecycle.OnLifecycleEvent
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import java.io.File

class MainActivity : AppCompatActivity(), LifecycleObserver {

    private lateinit var engine: LuduvoEngine
    private lateinit var surfaceView: LuduvoSurfaceView
    private lateinit var layout: FrameLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Fullscreen immersive mode
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.setStatusBarColor(android.graphics.Color.TRANSPARENT)
        window.setNavigationBarColor(android.graphics.Color.TRANSPARENT)

        val controller = WindowInsetsControllerCompat(window, layout)
        controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        controller.hide(WindowInsetsCompat.Type.systemBars())

        // Load native library early
        LuduvoEngine.loadLibrary()

        // Create engine and surface view
        engine = LuduvoEngine(this)
        surfaceView = LuduvoSurfaceView(this, engine)
        layout = FrameLayout(this).apply {
            addView(surfaceView, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            ))
        }
        setContentView(layout)

        lifecycle.addObserver(this)
        lifecycle.addObserver(engine)

        // Handle deep links (luduvo:// and buildoverse://)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        intent?.data?.let { uri ->
            if (uri.scheme == "luduvo" || uri.scheme == "buildoverse") {
                // luduvo://<token>/<host>/<port>/<pubkey>
                val config = buildConfigFromUri(uri)
                launch(Dispatchers.IO) {
                    writeConfigFile(config)
                    engine.start(config.absolutePath)
                }
            }
        }
    }

    private data class JoinConfig(
        val token: String,
        val host: String,
        val port: Int,
        val pubkey: String
    )

    private fun buildConfigFromUri(uri: Uri): JoinConfig {
        val path = uri.path?.removePrefix("/") ?: ""
        val parts = path.split("/")
        return JoinConfig(
            token = parts.getOrNull(0) ?: "",
            host = parts.getOrNull(1) ?: "194.163.173.138",
            port = parts.getOrNull(2)?.toIntOrNull() ?: 55000,
            pubkey = parts.getOrNull(3) ?: ""
        )
    }

    private fun writeConfigFile(config: JoinConfig): File {
        val dir = getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS) ?: filesDir
        val file = File(dir, "luduvo_join.json")
        val json = """
            {
                "token": "${config.token}",
                "host": "${config.host}",
                "port": ${config.port},
                "pubkey": "${config.pubkey}"
            }
        """.trimIndent()
        file.writeText(json)
        return file
    }

    @OnLifecycleEvent(Lifecycle.Event.ON_RESUME)
    fun onResume() {
        // Keep screen on during gameplay
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    @OnLifecycleEvent(Lifecycle.Event.ON_PAUSE)
    fun onPause() {
        window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    @OnLifecycleEvent(Lifecycle.Event.ON_DESTROY)
    fun onDestroyEngine() {
        engine.stop()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // Handle runtime permissions if needed
    }
}