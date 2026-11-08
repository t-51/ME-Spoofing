package com.kigaping.mespoofing

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Keeps a user-started local proxy session visible as an Android foreground service.
 * The service raises process importance but cannot prevent force-stop or every
 * vendor-specific battery restriction.
 */
class ProxyForegroundService : Service() {

    companion object {
        const val ACTION_START  = "com.kigaping.mespoofing.SERVICE_START"
        const val ACTION_STOP   = "com.kigaping.mespoofing.SERVICE_STOP"
        const val ACTION_CANCEL = "com.kigaping.mespoofing.SERVICE_CANCEL"
        const val ACTION_UPDATE = "com.kigaping.mespoofing.SERVICE_UPDATE"
        const val ACTION_EXPIRED = "com.kigaping.mespoofing.SERVICE_EXPIRED"

        const val EXTRA_TITLE   = "title"
        const val EXTRA_CONTENT = "content"

        private const val CHANNEL_ID       = "snispoof_fg_service"
        private const val EXPIRED_CHANNEL_ID = "snispoof_expired"
        private const val NOTIFICATION_ID  = 1001
        private const val EXPIRED_NOTIFICATION_ID = 1002
        private const val TIME_WARNING_NOTIFICATION_ID = 1003

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    // ─── Lifecycle ───────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        createExpiredNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {

            ACTION_EXPIRED -> {
                val title = intent.getStringExtra(EXTRA_TITLE)
                    ?: "ME Spoofing - زمان اتصال تمام شد"
                val content = intent.getStringExtra(EXTRA_CONTENT)
                    ?: "برای تمدید زمان، برنامه را باز کنید و تبلیغ پاداشی را تماشا کنید."
                val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                nm.notify(
                    EXPIRED_NOTIFICATION_ID,
                    buildNotification(
                        title,
                        content,
                        connected = false,
                        channelId = EXPIRED_CHANNEL_ID,
                        ongoing = false
                    )
                )
                isRunning = false
                stopForegroundCompat()
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_STOP, ACTION_CANCEL -> {
                isRunning = false
                if (intent.action == ACTION_STOP) {
                    ProxyApplication.methodChannel?.invokeMethod("onAction", "disconnect")
                }
                stopForegroundCompat()
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_UPDATE -> {
                val title   = intent.getStringExtra(EXTRA_TITLE)   ?: return START_STICKY
                val content = intent.getStringExtra(EXTRA_CONTENT) ?: return START_STICKY
                currentTitle = title
                currentContent = content
                val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                nm.notify(NOTIFICATION_ID, buildNotification(title, content, connected = true))
                return START_STICKY
            }

            else -> { // ACTION_START or null (system restart via START_STICKY)
                val title   = intent?.getStringExtra(EXTRA_TITLE)   ?: "ME Spoofing"
                val content = intent?.getStringExtra(EXTRA_CONTENT) ?: "پروکسی در حال اجراست…"
                currentTitle = title
                currentContent = content
                val notificationManager =
                    getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancel(EXPIRED_NOTIFICATION_ID)
                notificationManager.cancel(TIME_WARNING_NOTIFICATION_ID)

                val notification = buildNotification(title, content, connected = true)
                startAsForeground(notification)
                isRunning = true
                return START_STICKY
            }
        }
    }

    /** Keep the foreground notification current after the task leaves recents. */
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        currentTitle = "ME Spoofing - فعال در پس‌زمینه 🛡️"
        currentContent = "پروکسی در حال اجرا در پس‌زمینه است"
        startAsForeground(
            buildNotification(
                currentTitle,
                currentContent,
                connected = true
            )
        )
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ─── Notification helpers ────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "ME Spoofing سرویس",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "فعال‌سازی پراکسی ME Spoofing در پس‌زمینه"
                setShowBadge(false)
                setSound(null, null)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm?.createNotificationChannel(channel)
        }
    }

    private fun createExpiredNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                EXPIRED_CHANNEL_ID,
                "پایان زمان اتصال",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "اعلان پایان زمان و نیاز به تمدید اتصال"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(
        title: String,
        content: String,
        connected: Boolean,
        channelId: String = CHANNEL_ID,
        ongoing: Boolean = connected
    ): Notification {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else
            PendingIntent.FLAG_UPDATE_CURRENT

        // Tap notification → open app
        val openIntent = Intent(this, MainActivity::class.java).apply {
            this.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPi = PendingIntent.getActivity(this, 0, openIntent, flags)

        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.drawable.ic_stat_shield)
            .setContentTitle(title)
            .setContentText(content)
            .setStyle(NotificationCompat.BigTextStyle().bigText(content))
            .setContentIntent(openPi)
            .setOngoing(ongoing)
            .setOnlyAlertOnce(true)
            .setPriority(
                if (ongoing) NotificationCompat.PRIORITY_LOW
                else NotificationCompat.PRIORITY_DEFAULT
            )
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setAutoCancel(!ongoing)

        if (connected) {
            // "قطع اتصال" action button
            val stopIntent = Intent(this, ProxyForegroundService::class.java)
                .setAction(ACTION_STOP)
            val stopPi = PendingIntent.getService(this, 1, stopIntent, flags)
            builder.addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "قطع اتصال",
                stopPi
            )
        }

        return builder.build()
    }

    private fun startAsForeground(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                @Suppress("DEPRECATION")
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                )
            }
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private var currentTitle = "ME Spoofing"
    private var currentContent = "پروکسی در حال اجراست…"

    @Suppress("DEPRECATION")
    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
    }
}
