package com.example.background_file_uploader

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class NotificationHelper(private val context: Context) {
    
    companion object {
        private const val CHANNEL_ID = "background_file_uploader"
        private const val CHANNEL_NAME = "File Uploads"
        private const val CHANNEL_DESCRIPTION = "Notifications for file upload progress"
    }

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, importance).apply {
                description = CHANNEL_DESCRIPTION
            }
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun buildProgressNotification(
        uploadId: String,
        title: String,
        description: String,
        progress: Int,
        maxProgress: Int = 100
    ): android.app.Notification {
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(description)
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .setProgress(maxProgress, progress, false)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    fun buildCompletedNotification(
        title: String,
        description: String,
        isSuccess: Boolean
    ): android.app.Notification {
        val icon = if (isSuccess) {
            android.R.drawable.stat_sys_upload_done
        } else {
            android.R.drawable.stat_notify_error
        }

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(description)
            .setSmallIcon(icon)
            .setOngoing(false)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()
    }

    fun showNotification(notificationId: Int, notification: android.app.Notification) {
        try {
            NotificationManagerCompat.from(context).notify(notificationId, notification)
        } catch (e: SecurityException) {
            // Permission not granted, skip notification
        }
    }

    fun cancelNotification(notificationId: Int) {
        NotificationManagerCompat.from(context).cancel(notificationId)
    }

    fun getNotificationId(uploadId: String): Int {
        return uploadId.hashCode()
    }
}
