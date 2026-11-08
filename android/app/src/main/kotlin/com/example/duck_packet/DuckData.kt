package com.example.duck_packet

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/** Dữ liệu dùng chung cho 5 widget (Flutter gửi sang qua kênh duckpacket/widget). */
object DuckData {
    private const val PREFS = "duck_widget"

    // Cùng thứ tự với enum DuckFace trong duck_mood.dart
    private val FACES = arrayOf(
        "surprised", "dizzy", "happy", "crying", "bored", "cool", "cheer", "confused",
        "love", "sleeping", "angry", "shy", "shocked", "determined", "worried"
    )

    fun sp(ctx: Context): SharedPreferences = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun vi(): Boolean = Locale.getDefault().language == "vi"

    fun save(ctx: Context, a: Map<*, *>) {
        val e = sp(ctx).edit()
        e.putInt("streak", (a["streak"] as? Number)?.toInt() ?: 0)
        e.putInt("freezes", (a["freezes"] as? Number)?.toInt() ?: 0)
        e.putInt("wrong", (a["wrong"] as? Number)?.toInt() ?: 0)
        e.putString("lastDay", a["lastDay"] as? String ?: "")
        e.putString("days", a["days"] as? String ?: "")
        e.putString("glossary", a["glossary"] as? String ?: "[]")
        e.putString("dueDays", a["dueDays"] as? String ?: "")
        e.putString("exam", a["exam"] as? String ?: "")
        e.putString("weak", a["weak"] as? String ?: "")
        e.apply()
    }

    fun key(c: Calendar): String = String.format(
        Locale.US, "%04d-%02d-%02d",
        c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH)
    )

    fun todayKey(): String = key(Calendar.getInstance())

    fun dayNumOf(k: String): Long? {
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

    fun todayNum(): Long = dayNumOf(todayKey()) ?: 0L

    private fun slotHash(slot: Long): Int =
        ((((slot * 2654435761L) % 4294967296L) / 256L) % FACES.size).toInt()

    // Cùng công thức với _faceIndexForSlot trong duck_mood.dart (đổi mặt mỗi 8 giờ)
    fun faceName(): String {
        val now = System.currentTimeMillis()
        val slot = (now + TimeZone.getDefault().getOffset(now)) / 28_800_000L
        val cur = slotHash(slot)
        val prev = slotHash(slot - 1)
        val idx = if (cur == prev) (cur + 1) % FACES.size else cur
        return FACES[idx]
    }

    fun duckRes(ctx: Context): Int =
        ctx.resources.getIdentifier("duck_mood_" + faceName(), "drawable", ctx.packageName)

    /** Số ngày chuỗi đang hiển thị: tính cả Streak Freeze, quá hạn thì về 0. */
    fun streakShown(ctx: Context): Int {
        val s = sp(ctx)
        val streak = s.getInt("streak", 0)
        val freezes = s.getInt("freezes", 0)
        val last = dayNumOf(s.getString("lastDay", "") ?: "") ?: return 0
        val missed = todayNum() - last - 1
        return if (missed <= 0L || missed <= freezes.toLong()) streak else 0
    }

    fun doneDays(ctx: Context): Set<String> =
        (sp(ctx).getString("days", "") ?: "").split(",").filter { it.isNotEmpty() }.toSet()

    fun refreshAll(ctx: Context) {
        val mgr = AppWidgetManager.getInstance(ctx)
        upd(ctx, mgr, DuckWidgetProvider::class.java) { DuckViews.streak(it) }
        upd(ctx, mgr, DuckTermWidget::class.java) { DuckViews.term(it) }
        upd(ctx, mgr, DuckReviewWidget::class.java) { DuckViews.review(it) }
        upd(ctx, mgr, DuckExamWidget::class.java) { DuckViews.exam(it) }
        upd(ctx, mgr, DuckMiniWidget::class.java) { DuckViews.mini(it) }
    }

    private fun upd(ctx: Context, mgr: AppWidgetManager, cls: Class<*>, build: (Context) -> RemoteViews) {
        for (id in mgr.getAppWidgetIds(ComponentName(ctx, cls))) mgr.updateAppWidget(id, build(ctx))
    }
}
