DUCKPACKET v5 (thay cho v4)  AI không có Flutter/Android SDK. Chưa biên dịch. Dán log thật nếu lỗi.
Giải nén ĐÈ lên duck_packet/ (sau v3).

Dart:   lib/study.dart, home_screen.dart, duck_mood.dart, widget_sync.dart, settings_screen.dart
Android: AndroidManifest.xml, MainActivity.kt, DuckData.kt, DuckViews.kt, DuckWidgetProvider.kt, DuckWidgets.kt,
         res/layout, res/xml, res/drawable, res/drawable-nodpi

5 widget (giữ lâu màn hình chính -> Widgets -> DuckPacket):
  Streak (4x2)  Term of the day (4x2)  Review (3x2)  Exam countdown (3x2)  Mini (1x1)
Ngày thi: Settings -> Exam date.

git add .
git commit -m "Five Android widgets, exam date setting"
git push origin main
