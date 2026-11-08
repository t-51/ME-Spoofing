package com.kigaping.mespoofing

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.content.Context
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private val NOTIF_PERMISSION_CODE = 2001

    override fun provideFlutterEngine(context: Context): FlutterEngine {
        return (application as ProxyApplication).flutterEngine
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Request notification permission on engine start (Android 13+)
        requestNotificationPermission()

        // Request battery optimization exemption so Android doesn't freeze the proxy
        requestBatteryOptimizationExemption()
    }

    // ─── Permission helpers ───────────────────────────────────────────────────

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this, Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIF_PERMISSION_CODE
                )
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // Permission result handled; service will retry notification on next connect
    }

    /**
     * Ask the user to exclude this app from battery optimization.
     * Without this, Android aggressively suspends the app process after a few
     * minutes in the background, killing the proxy even with a Foreground Service
     * on some vendors (Xiaomi, Huawei, Samsung).
     */
    private fun requestBatteryOptimizationExemption() {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            } catch (error: Exception) {
                android.util.Log.w(
                    "MainActivity",
                    "Unable to open battery optimization settings",
                    error
                )
            }
        }
    }

    // ─── Activity lifecycle ───────────────────────────────────────────────────

    override fun onDestroy() {
        // Do NOT stop the service here — it must keep running in background
        super.onDestroy()
    }
}
