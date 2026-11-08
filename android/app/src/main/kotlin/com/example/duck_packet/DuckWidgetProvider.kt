package com.example.duck_packet

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.widget.RemoteViews
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

class DuckWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) appWidgetManager.updateAppWidget(id, build(context))
    }

    companion object {
        private const val PREFS = "duck_widget"

        // Cùng thứ tự với enum DuckFace trong duck_mood.dart
        private val FACES = arrayOf(
            "surprised", "dizzy", "happy", "crying", "bored", "cool", "cheer", "confused",
            "love", "sleeping", "angry", "shy", "shocked", "determined", "worried"
        )
        private val LBL = intArrayOf(R.id.lbl0, R.id.lbl1, R.id.lbl2, R.id.lbl3, R.id.lbl4, R.id.lbl5, R.id.lbl6)
        private val DOT = intArrayOf(R.id.dot0, R.id.dot1, R.id.dot2, R.id.dot3, R.id.dot4, R.id.dot5, R.id.dot6)

        fun save(ctx: Context, streak: Int, lastDay: String, freezes: Int, days: String) {
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putInt("streak", streak)
                .putString("lastDay", lastDay)
                .putInt("freezes", freezes)
                .putString("days", days)
                .apply()
        }

        fun refreshAll(ctx: Context) {
            val mgr = AppWidgetManager.getInstance(ctx)
            val ids = mgr.getAppWidgetIds(ComponentName(ctx, DuckWidgetProvider::class.java))
            for (id in ids) mgr.updateAppWidget(id, build(ctx))
        }

        private fun key(c: Calendar): String = String.format(
            Locale.US, "%04d-%02d-%02d",
            c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH)
        )

        private fun dayNumOf(k: String): Long? {
            val p = k.split("-")
            if (p.size != 3) return null
            val y = p[0].toIntOrNull() ?: return null
            val m = p[1].toIntOrNull() ?: return null
            val d = p[2].toIntOrNull() ?: return null
            val c = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
            c.clear()
            c.set(y, m - 1, d)
            return c.timeInMillis / 86_400_000L
        }

        private fun slotHash(slot: Long): Int =
            ((((slot * 2654435761L) % 4294967296L) / 256L) % FACES.size).toInt()

        // Cùng công thức với _faceIndexForSlot trong duck_mood.dart (đổi mặt mỗi 8 giờ)
        private fun faceName(): String {
            val now = System.currentTimeMillis()
            val slot = (now + TimeZone.getDefault().getOffset(now)) / 28_800_000L
            val cur = slotHash(slot)
            val prev = slotHash(slot - 1)
            val idx = if (cur == prev) (cur + 1) % FACES.size else cur
            return FACES[idx]
        }

        fun build(ctx: Context): RemoteViews {
            val sp = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val streak = sp.getInt("streak", 0)
            val lastDay = sp.getString("lastDay", "") ?: ""
            val freezes = sp.getInt("freezes", 0)
            val days = (sp.getString("days", "") ?: "").split(",").filter { it.isNotEmpty() }.toSet()
            val vi = Locale.getDefault().language == "vi"

            val today = Calendar.getInstance()
            val todayKey = key(today)
            val todayNum = dayNumOf(todayKey) ?: 0L
            val lastNum = dayNumOf(lastDay)
            val missed = if (lastNum == null) 0L else todayNum - lastNum - 1
            val shown = if (lastNum == null) 0 else if (missed <= 0L || missed <= freezes.toLong()) streak else 0
            val doneToday = lastDay == todayKey || days.contains(todayKey)

            val rv = RemoteViews(ctx.packageName, R.layout.duck_widget)
            rv.setTextViewText(R.id.streak, shown.toString())
            rv.setTextViewText(R.id.streakLbl, if (vi) "ngày liên tiếp" else "day streak")
            rv.setTextViewText(
                R.id.msg,
                if (doneToday) (if (vi) "Hôm nay đã học xong!" else "Great job today!")
                else (if (vi) "Học thôi nào!" else "Time to study!")
            )

            val letters = if (vi) arrayOf("2", "3", "4", "5", "6", "7", "CN") else arrayOf("M", "T", "W", "T", "F", "S", "S")
            val dow = (today.get(Calendar.DAY_OF_WEEK) + 5) % 7 // Thứ 2 = 0 ... CN = 6
            for (i in 0..6) {
                val c = Calendar.getInstance()
                c.add(Calendar.DAY_OF_MONTH, i - dow)
                val done = days.contains(key(c)) || (i == dow && doneToday)
                val isToday = i == dow
                rv.setTextViewText(LBL[i], letters[i])
                val bg = when {
                    done && isToday -> R.drawable.dot_done_today
                    done -> R.drawable.dot_done
                    isToday -> R.drawable.dot_today
                    else -> R.drawable.dot_off
                }
                rv.setInt(DOT[i], "setBackgroundResource", bg)
            }

            val resId = ctx.resources.getIdentifier("duck_mood_" + faceName(), "drawable", ctx.packageName)
            if (resId != 0) rv.setImageViewResource(R.id.duck, resId)

            val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
            if (launch != null) {
                val pi = PendingIntent.getActivity(
                    ctx, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                rv.setOnClickPendingIntent(R.id.root, pi)
            }
            return rv
        }
    }
}
