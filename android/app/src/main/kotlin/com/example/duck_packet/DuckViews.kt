package com.example.duck_packet

import android.app.PendingIntent
import android.content.Context
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar
import org.json.JSONArray

object DuckViews {
    private const val WHITE = "#FFFFFF"
    private const val SOFT = "#E6FFFFFF"
    private const val SUB_DARK = "#B0B8C2"
    private const val ORANGE = "#FFAE00"
    private const val GREEN = "#24C185"
    private const val BLUE = "#00BCEB"
    private const val RED = "#FB4B53"

    private fun c(s: String): Int = Color.parseColor(s)

    private val DONE_EN = arrayOf("Great job today!", "Streak is safe. Nice!", "The duck is proud of you!", "One more lesson?", "You're on fire!")
    private val DONE_VI = arrayOf("Hôm nay làm tốt lắm!", "Chuỗi an toàn rồi!", "Vịt tự hào về bạn!", "Thêm một bài nữa nhé?", "Bạn đang bùng cháy!")
    private val TODO_EN = arrayOf("Time to study!", "Keep your streak alive!", "Just one quick lesson", "The duck is waiting...", "5 minutes is enough!")
    private val TODO_VI = arrayOf("Học thôi nào!", "Giữ chuỗi nào!", "Chỉ cần một bài nhanh", "Vịt đang chờ bạn...", "5 phút là đủ!")
    private val CLEAR_EN = arrayOf("All caught up!", "Brain fully charged!", "Nothing to review. Nice!")
    private val CLEAR_VI = arrayOf("Đã ôn xong hết!", "Não đã nạp đầy năng lượng!", "Không còn gì để ôn. Tuyệt!")

    private fun base(ctx: Context, layout: Int, face: String? = null): RemoteViews {
        val rv = RemoteViews(ctx.packageName, layout)
        val res = if (face != null) DuckData.faceRes(face) else DuckData.duckRes(ctx)
        if (res != 0) rv.setImageViewResource(R.id.duck, res)
        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
        if (launch != null) {
            val pi = PendingIntent.getActivity(
                ctx, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            rv.setOnClickPendingIntent(R.id.root, pi)
        }
        return rv
    }

    private val LBL = intArrayOf(R.id.lbl0, R.id.lbl1, R.id.lbl2, R.id.lbl3, R.id.lbl4, R.id.lbl5, R.id.lbl6)
    private val DOT = intArrayOf(R.id.dot0, R.id.dot1, R.id.dot2, R.id.dot3, R.id.dot4, R.id.dot5, R.id.dot6)

    // 1) Chuỗi ngày + 7 ngày trong tuần + nhiệm vụ hôm nay
    fun streak(ctx: Context): RemoteViews {
        val vi = DuckData.vi()
        val dark = DuckData.isDark(ctx)
        val days = DuckData.doneDays(ctx)
        val doneToday = DuckData.doneToday(ctx)
        val streak = DuckData.streakShown(ctx)
        val q = DuckData.questsDone(ctx)

        val rv = base(ctx, R.layout.duck_widget)
        rv.setInt(R.id.root, "setBackgroundResource", if (dark) R.drawable.bg_dark else R.drawable.bg_cyan)
        val sub = c(if (dark) SUB_DARK else SOFT)
        rv.setTextColor(R.id.streak, c(if (dark) ORANGE else WHITE))
        rv.setTextColor(R.id.streakLbl, sub)
        rv.setTextColor(R.id.quest, sub)

        val tier = when {
            streak >= 100 -> "👑"
            streak >= 30 -> "🏆"
            streak >= 7 -> "🌟"
            streak >= 1 -> "🔥"
            else -> "💤"
        }
        rv.setTextViewText(R.id.fire, tier)
        rv.setTextViewText(R.id.streak, streak.toString())
        rv.setTextViewText(R.id.streakLbl, if (vi) "ngày liên tiếp" else "day streak")

        val msg = when {
            doneToday && (streak == 7 || streak == 30 || streak == 100) ->
                if (vi) "Cột mốc $streak ngày!" else "$streak-day milestone!"
            doneToday -> DuckData.pick(if (vi) DONE_VI else DONE_EN)
            streak > 0 && DuckData.hour() >= 18 ->
                if (vi) "Đừng để mất chuỗi $streak ngày!" else "Don't lose your $streak-day streak!"
            else -> DuckData.pick(if (vi) TODO_VI else TODO_EN)
        }
        rv.setTextViewText(R.id.msg, msg)
        val dots = (0..2).joinToString("") { if (it < q) "●" else "○" }
        rv.setTextViewText(R.id.quest, (if (vi) "NV " else "Quests ") + dots)

        val letters = if (vi) arrayOf("2", "3", "4", "5", "6", "7", "CN") else arrayOf("M", "T", "W", "T", "F", "S", "S")
        val dow = (Calendar.getInstance().get(Calendar.DAY_OF_WEEK) + 5) % 7 // Thứ 2 = 0 ... CN = 6
        for (i in 0..6) {
            val cal = Calendar.getInstance()
            cal.add(Calendar.DAY_OF_MONTH, i - dow)
            val isToday = i == dow
            val done = days.contains(DuckData.key(cal)) || (isToday && doneToday)
            rv.setTextViewText(LBL[i], letters[i])
            rv.setTextColor(LBL[i], sub)
            val bg = when {
                done && isToday -> R.drawable.dot_done_today
                done -> R.drawable.dot_done
                isToday -> R.drawable.dot_today
                else -> R.drawable.dot_off
            }
            rv.setInt(DOT[i], "setBackgroundResource", bg)
        }
        return rv
    }

    // 2) Thuật ngữ trong ngày (từ Glossary), nền terminal tối ở cả hai chế độ
    fun term(ctx: Context): RemoteViews {
        val vi = DuckData.vi()
        val rv = base(ctx, R.layout.duck_term_widget)
        rv.setTextViewText(R.id.tHead, if (vi) "Thuật ngữ hôm nay" else "Term of the day")
        var term = ""
        var def = ""
        var cmd = ""
        var tag = ""
        try {
            val arr = JSONArray(DuckData.sp(ctx).getString("glossary", "[]") ?: "[]")
            if (arr.length() > 0) {
                val o = arr.getJSONObject((DuckData.todayNum() % arr.length()).toInt())
                term = o.optString("t")
                def = o.optString("d")
                cmd = o.optString("c")
                tag = o.optString("g")
            }
        } catch (e: Exception) {
        }
        if (term.isEmpty()) {
            term = "DuckPacket"
            def = if (vi) "Nhập một khóa học có phần glossary để xem thuật ngữ mỗi ngày." else "Import a course with a glossary to see a term every day."
        }
        rv.setTextViewText(R.id.tTerm, term)
        rv.setTextViewText(R.id.tDef, def)
        rv.setTextViewText(R.id.tCmd, cmd)
        rv.setViewVisibility(R.id.tCmd, if (cmd.isEmpty()) View.GONE else View.VISIBLE)
        rv.setTextViewText(R.id.tTag, tag)
        rv.setViewVisibility(R.id.tTag, if (tag.isEmpty()) View.GONE else View.VISIBLE)
        return rv
    }

    // 3) Số câu cần ôn hôm nay + thanh tiến độ + số câu sai
    fun review(ctx: Context): RemoteViews {
        val vi = DuckData.vi()
        val dark = DuckData.isDark(ctx)
        val sp = DuckData.sp(ctx)
        val today = DuckData.todayNum()
        val due = (sp.getString("dueDays", "") ?: "").split(",").mapNotNull { it.toLongOrNull() }.count { it <= today }
        val wrong = sp.getInt("wrong", 0)
        val clear = due == 0 && wrong == 0
        val dueBase = if (sp.getLong("dueBaseDay", -1L) == today) maxOf(sp.getInt("dueBase", 0), due) else due
        val pct = if (dueBase <= 0) 100 else ((dueBase - due) * 100 / dueBase).coerceIn(0, 100)

        val rv = base(ctx, R.layout.duck_review_widget, if (clear) "love" else null)
        rv.setInt(R.id.root, "setBackgroundResource", if (dark) R.drawable.bg_dark else R.drawable.bg_green)
        rv.setTextColor(R.id.rNum, c(if (dark) GREEN else WHITE))
        rv.setTextColor(R.id.rLbl, c(if (dark) SUB_DARK else "#F2FFFFFF"))
        rv.setTextViewText(R.id.rNum, due.toString())
        rv.setTextViewText(R.id.rLbl, if (vi) "câu cần ôn hôm nay" else "to review today")
        rv.setProgressBar(R.id.rBar, 100, pct, false)
        val msg = when {
            clear -> DuckData.pick(if (vi) CLEAR_VI else CLEAR_EN)
            wrong > 0 -> if (vi) "$wrong câu sai cần sửa" else "$wrong mistakes to fix"
            else -> if (vi) "Ôn nhanh cho nhớ lâu!" else "A quick review sticks!"
        }
        rv.setTextViewText(R.id.rMsg, msg)
        return rv
    }

    // 4) Đếm ngược ngày thi (đỏ khi còn <= 7 ngày)
    fun exam(ctx: Context): RemoteViews {
        val vi = DuckData.vi()
        val dark = DuckData.isDark(ctx)
        val sp = DuckData.sp(ctx)
        val examNum = DuckData.dayNumOf(sp.getString("exam", "") ?: "")
        val weak = sp.getString("weak", "") ?: ""
        var num = "—"
        var lbl = if (vi) "Đặt ngày thi trong Cài đặt" else "Set your exam date in Settings"
        var showWeak = false
        var urgent = false
        if (examNum != null) {
            val left = examNum - DuckData.todayNum()
            if (left > 0L) {
                num = left.toString()
                lbl = if (vi) "ngày nữa là thi" else "days to exam"
                showWeak = weak.isNotEmpty()
                if (left <= 7L) urgent = true
            } else if (left == 0L) {
                num = "0"
                lbl = if (vi) "Hôm nay thi! Chúc may mắn!" else "Exam day! Good luck!"
                urgent = true
            } else {
                lbl = if (vi) "Ngày thi đã qua" else "Exam date has passed"
            }
        }
        val rv = base(ctx, R.layout.duck_exam_widget, if (urgent) "determined" else null)
        val bg = when {
            dark -> R.drawable.bg_dark
            urgent -> R.drawable.bg_red
            else -> R.drawable.bg_blue
        }
        rv.setInt(R.id.root, "setBackgroundResource", bg)
        rv.setTextColor(R.id.eNum, c(if (dark) (if (urgent) RED else BLUE) else WHITE))
        rv.setTextColor(R.id.eLbl, c(if (dark) SUB_DARK else "#F2FFFFFF"))
        rv.setTextViewText(R.id.eNum, num)
        rv.setTextViewText(R.id.eLbl, lbl)
        rv.setTextViewText(R.id.eWeak, (if (vi) "Cần luyện: " else "Focus: ") + weak)
        rv.setViewVisibility(R.id.eWeak, if (showWeak) View.VISIBLE else View.GONE)
        return rv
    }

    // 5) Nhỏ 1x1: vịt + số chuỗi
    fun mini(ctx: Context): RemoteViews {
        val dark = DuckData.isDark(ctx)
        val streak = DuckData.streakShown(ctx)
        val rv = base(ctx, R.layout.duck_mini_widget)
        rv.setInt(R.id.root, "setBackgroundResource", if (dark) R.drawable.bg_dark else R.drawable.bg_cyan)
        val tier = when {
            streak >= 100 -> "👑"
            streak >= 30 -> "🏆"
            streak >= 7 -> "🌟"
            streak >= 1 -> "🔥"
            else -> "💤"
        }
        rv.setTextViewText(R.id.mBadge, "$tier $streak")
        return rv
    }
}
