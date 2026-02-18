package com.example.lexity_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Person
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build

object BubbleController {
    private const val CHANNEL_ID = "lexity_bubble_channel"
    private const val SHORTCUT_ID = "lexity_translator"

    fun showBubble(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        // 1. Create Channel
        if (notificationManager.getNotificationChannel(CHANNEL_ID) == null) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Translator Bubbles",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Chat bubbles for translation"
                setAllowBubbles(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // 2. Prepare Intent for BubbleActivity
        val target = Intent(context, BubbleActivity::class.java)
        val bubbleIntent = PendingIntent.getActivity(
            context, 0, target,
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        // 3. Create Dynamic Shortcut (Required for Android 11+)
        val icon = Icon.createWithResource(context, R.mipmap.ic_launcher)
        val person = Person.Builder()
            .setName("Lexity AI")
            .setIcon(icon)
            .setImportant(true)
            .build()

        val shortcut = ShortcutInfo.Builder(context, SHORTCUT_ID)
            .setLongLived(true)
            .setIntent(target.setAction(Intent.ACTION_VIEW))
            .setShortLabel("Translator")
            .setIcon(icon)
            .setPerson(person)
            .build()

        context.getSystemService(ShortcutManager::class.java)!!.pushDynamicShortcut(shortcut)

        // 4. Build Bubble Metadata
        val bubbleData = Notification.BubbleMetadata.Builder(bubbleIntent, icon)
            .setDesiredHeight(600)
            .setAutoExpandBubble(true)
            .setSuppressNotification(true)
            .build()

        // 5. Show Notification
        val builder = Notification.Builder(context, CHANNEL_ID)
            .setContentIntent(bubbleIntent)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setBubbleMetadata(bubbleData)
            .addPerson(person)
            .setShortcutId(SHORTCUT_ID)
            .setContentTitle("Lexity Translator")
            .setContentText("Tap to translate...")
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setStyle(Notification.MessagingStyle(person)
                .setConversationTitle("Translation")
                .addMessage("Ready", System.currentTimeMillis(), person)
            )

        notificationManager.notify(1001, builder.build())
    }
}
