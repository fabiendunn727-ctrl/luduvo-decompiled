package com.luduvo.client

import android.app.Application
import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.util.Log

class LuduvoApplication : Application() {

    companion object {
        private const val TAG = "LuduvoApplication"
        var versionName: String = "1.0.0"
        var versionCode: Int = 1
    }

    override fun onCreate() {
        super.onCreate()
        loadVersionInfo()
        Log.i(TAG, "Luduvo Application started v$versionName ($versionCode)")
    }

    private fun loadVersionInfo() {
        try {
            val info: PackageInfo = packageManager.getPackageInfo(packageName, 0)
            versionName = info.versionName ?: "1.0.0"
            versionCode = info.longVersionCode.toInt()
        } catch (e: PackageManager.NameNotFoundException) {
            Log.e(TAG, "Failed to load version info", e)
        }
    }
}