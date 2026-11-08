package com.example.duck_packet

import android.app.PendingIntent
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar
import org.json.JSONArray

object DuckViews {

    private fun base(ctx: Context, layout: Int): RemoteViews {
        val rv = RemoteViews(ctx.packageName, layout)
        val res = DuckData.duckRes(ctx)
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

    // 1) Chuỗi ngày + 7 ngày trong tuần
    fun streak(ctx: Context): RemoteViews {
        val vi = DuckData.vi()
        val days = DuckData.doneDays(ctx)
        val sp = DuckData.sp(ctx)
        val lastDay = sp.getString("lastDay", "") ?: ""
        val todayKey = DuckData.todayKey()
        val doneToday = lastDay == todayKey || days.contains(todayKey)

        val rv = base(ctx, R.layout.duck_widget)
        rv.setTextViewText(R.id.streak, DuckData.streakShown(ctx).toString())
        rv.setTextViewText(R.id.streakLbl, if (vi) "ngày liên tiếp" else "day streak")
        rv.setTextViewText(
            R.id.msg,
            if (doneToday) (if (vi) "Hôm nay đã học xong!" else "Great job today!")
            else (if (vi) "Học thôi nào!" else "Time to study!")
        )
        val letters = if (vi) arrayOf("2", "3", "4", "5", "6", "7", "CN") else arrayOf("M", "T", "W", "T", "F", "S", "S")
        val dow = (Calendar.getInstance().get(Calendar.DAY_OF_WEEK) + 5) % 7 // Thứ 2 = 0 ... CN = 6
        for (i in 0..6) {
            val c = Calendar.getInstance()
            c.add(Calendar.DAY_OF_MONTH, i - dow)
            val isToday = i == dow
            val done = days.contains(DuckData.key(c)) || (isToday && doneToday)
            rv.setTextViewText(LBL[i], letters[i])
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

    // 2) Thuật ngữ trong ngày (từ Glossary)
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

    // 3) Số câu cần ôn hôm nay + số câu sai
    fun review(ctx: Context): RemoteViews {
        val vi = DuckData.vi()
        val sp = DuckData.sp(ctx)
        val today = DuckData.todayNum()
        val due = (sp.getString("dueDays", "") ?: "").split(",").mapNotNull { it.toLongOrNull() }.count { it <= today }
        val wrong = sp.getInt("wrong", 0)
        val rv = base(ctx, R.layout.duck_review_widget)
        rv.setTextViewText(R.id.rNum, due.toString())
        rv.setTextViewText(R.id.rLbl, if (vi) "câu cần ôn hôm nay" else "to review today")
        rv.setTextViewText(
            R.id.rMsg,
            if (due == 0 && wrong == 0) (if (vi) "Đã ôn xong hết!" else "All caught up!")
            else if (vi) "$wrong câu sai cần sửa" else "$wrong mistakes to fix"
        )
        return rv
    }

    // 4) Đếm ngược ngày thi
    fun exam(ctx: Context): RemoteViews {
        val vi = DuckData.vi()
        val sp = DuckData.sp(ctx)
        val examNum = DuckData.dayNumOf(sp.getString("exam", "") ?: "")
        val weak = sp.getString("weak", "") ?: ""
        val rv = base(ctx, R.layout.duck_exam_widget)
        var num = "—"
        var lbl = if (vi) "Đặt ngày thi trong Cài đặt" else "Set your exam date in Settings"
        var showWeak = false
        if (examNum != null) {
            val left = examNum - DuckData.todayNum()
            if (left > 0L) {
                num = left.toString()
                lbl = if (vi) "ngày nữa là thi" else "days to exam"
                showWeak = weak.isNotEmpty()
            } else if (left == 0L) {
                num = "0"
                lbl = if (vi) "Hôm nay thi! Chúc may mắn!" else "Exam day! Good luck!"
            } else {
                lbl = if (vi) "Ngày thi đã qua" else "Exam date has passed"
            }
        }
        rv.setTextViewText(R.id.eNum, num)
        rv.setTextViewText(R.id.eLbl, lbl)
        rv.setTextViewText(R.id.eWeak, (if (vi) "Cần luyện: " else "Focus: ") + weak)
        rv.setViewVisibility(R.id.eWeak, if (showWeak) View.VISIBLE else View.GONE)
        return rv
    }

    // 5) Nhỏ 1x1: vịt + số chuỗi
    fun mini(ctx: Context): RemoteViews {
        val rv = base(ctx, R.layout.duck_mini_widget)
        rv.setTextViewText(R.id.mBadge, "🔥 " + DuckData.streakShown(ctx))
        return rv
    }
}
