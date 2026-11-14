package com.example.duck_packet

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
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

    // Tham chiếu tĩnh để trình rút gọn tài nguyên (shrinkResources) KHÔNG xóa ảnh vịt
    private val FACE_RES = intArrayOf(
        R.drawable.duck_mood_surprised, R.drawable.duck_mood_dizzy, R.drawable.duck_mood_happy,
        R.drawable.duck_mood_crying, R.drawable.duck_mood_bored, R.drawable.duck_mood_cool,
        R.drawable.duck_mood_cheer, R.drawable.duck_mood_confused, R.drawable.duck_mood_love,
        R.drawable.duck_mood_sleeping, R.drawable.duck_mood_angry, R.drawable.duck_mood_shy,
        R.drawable.duck_mood_shocked, R.drawable.duck_mood_determined, R.drawable.duck_mood_worried
    )

    fun sp(ctx: Context): SharedPreferences = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun vi(): Boolean = Locale.getDefault().language == "vi"

    fun save(ctx: Context, a: Map<*, *>) {
        val e = sp(ctx).edit()
        fun int(k: String) { if (a.containsKey(k)) e.putInt(k, (a[k] as? Number)?.toInt() ?: 0) }
        fun str(k: String, d: String) { if (a.containsKey(k)) e.putString(k, a[k] as? String ?: d) }
        int("streak"); int("freezes"); int("wrong"); int("quests")
        str("lastDay", ""); str("days", ""); str("glossary", "[]"); str("dueDays", "")
        str("exam", ""); str("weak", ""); str("theme", "auto")
        if (a.containsKey("dueDays")) {
            // mốc số câu cần ôn đầu ngày, để vẽ thanh tiến độ ở widget Review
            val today = todayNum()
            val due = ((a["dueDays"] as? String) ?: "").split(",").mapNotNull { it.toLongOrNull() }.count { it <= today }
            val s0 = sp(ctx)
            val base = if (s0.getLong("dueBaseDay", -1L) == today) maxOf(s0.getInt("dueBase", 0), due) else due
            e.putLong("dueBaseDay", today)
            e.putInt("dueBase", base)
        }
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

    fun faceRes(name: String): Int {
        val i = FACES.indexOf(name)
        return if (i >= 0) FACE_RES[i] else 0
    }

    fun hour(): Int = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)

    fun <T> pick(a: Array<T>): T = a[(todayNum() % a.size).toInt()]

    /** Sáng/tối theo cài đặt Appearance trong app (auto = theo hệ thống). */
    fun isDark(ctx: Context): Boolean = when (sp(ctx).getString("theme", "auto")) {
        "dark" -> true
        "light" -> false
        else -> (ctx.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
    }

    fun doneToday(ctx: Context): Boolean {
        val k = todayKey()
        return (sp(ctx).getString("lastDay", "") ?: "") == k || doneDays(ctx).contains(k)
    }

    fun questsDone(ctx: Context): Int = sp(ctx).getInt("quests", 0).coerceIn(0, 3)

    /** Mặt vịt theo trạng thái hôm nay; trạng thái trung tính thì dùng mặt ngẫu nhiên đổi mỗi 8 giờ. */
    fun stateFaceName(ctx: Context): String {
        val streak = streakShown(ctx)
        val h = hour()
        return when {
            doneToday(ctx) && questsDone(ctx) >= 3 -> "cheer"
            doneToday(ctx) && streak >= 30 -> "cool"
            doneToday(ctx) -> "happy"
            h in 0..5 -> "sleeping"
            h >= 21 && streak > 0 -> "worried"
            h >= 18 && streak > 0 -> "determined"
            else -> faceName()
        }
    }

    @Suppress("UNUSED_PARAMETER")
    fun duckRes(ctx: Context): Int = faceRes(stateFaceName(ctx))

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
