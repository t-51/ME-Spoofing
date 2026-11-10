package com.kigaping.mespoofing

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class ProxyApplication : Application() {

    lateinit var flutterEngine: FlutterEngine
        private set

    override fun onCreate() {
        super.onCreate()

        flutterEngine = FlutterEngine(this)
        configureChannels()
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
    }

    private fun configureChannels() {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SETTINGS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getFilesDir" -> result.success(filesDir.absolutePath)
                "getNativeLibraryDir" -> result.success(applicationInfo.nativeLibraryDir)
                else -> result.notImplemented()
            }
        }

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_CHANNEL
        )
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            val title = call.argument<String>("title") ?: "ME Spoofing"
            val content = call.argument<String>("content") ?: ""
            if (call.method == "showTimeWarning") {
                try {
                    showTimeWarningNotification(title, content)
                    result.success(true)
                } catch (error: Exception) {
                    result.error("TIME_WARNING_NOTIFICATION_ERROR", error.message, null)
                }
                return@setMethodCallHandler
            }

            val intent = Intent(this, ProxyForegroundService::class.java).apply {
                action = when (call.method) {
                    "startService" -> ProxyForegroundService.ACTION_START
                    "updateNotification", "showNotification" ->
                        ProxyForegroundService.ACTION_UPDATE
                    "cancelNotification" -> ProxyForegroundService.ACTION_CANCEL
                    "expireService" -> ProxyForegroundService.ACTION_EXPIRED
                    else -> null
                }
                putExtra(ProxyForegroundService.EXTRA_TITLE, title)
                putExtra(ProxyForegroundService.EXTRA_CONTENT, content)
            }

            if (intent.action == null) {
                result.notImplemented()
                return@setMethodCallHandler
            }

            try {
                if (call.method == "cancelNotification" ||
                    call.method == "expireService"
                ) {
                    startService(intent)
                } else if (
                    call.method == "updateNotification" ||
                    call.method == "showNotification"
                ) {
                    if (ProxyForegroundService.isRunning) {
                        startService(intent)
                    } else {
                        intent.action = ProxyForegroundService.ACTION_START
                        startForegroundService(intent)
                    }
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
                result.success(true)
            } catch (error: Exception) {
                result.error("PROXY_SERVICE_ERROR", error.message, null)
            }
        }
    }

    private fun showTimeWarningNotification(title: String, content: String) {
        val channelId = "snispoof_time_warning"
        val notificationManager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notificationManager.createNotificationChannel(
                NotificationChannel(
                    channelId,
                    "هشدار زمان اتصال",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "یادآوری نزدیک‌شدن به پایان زمان اتصال"
                    setShowBadge(false)
                }
            )
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val openIntent = Intent(this, MainActivity::class.java).apply {
            this.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.drawable.ic_stat_shield)
            .setContentTitle(title)
            .setContentText(content)
            .setStyle(NotificationCompat.BigTextStyle().bigText(content))
            .setContentIntent(PendingIntent.getActivity(this, 1003, openIntent, flags))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        notificationManager.notify(1003, notification)
    }

    companion object {
        private const val SETTINGS_CHANNEL = "com.kigaping.mespoofing/settings_path"
        private const val NOTIFICATION_CHANNEL = "com.kigaping.mespoofing/notification"

        @Volatile
        var methodChannel: MethodChannel? = null
            private set
    }
}
