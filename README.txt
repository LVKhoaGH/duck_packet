DuckPacket v10d  (TỔNG HỢP v10a + v10b + v10c + v10d; giải nén đè vào duck_packet/, CHƯA biên dịch)

SAU KHI ĐÈ: flutter pub get, rồi DỪNG HẲN app và chạy lại.

FILE MỚI
  lib/quests.dart, lib/quests_screen.dart, lib/i18n_vi_meta.dart     nhiệm vụ ngày, 45 huy hiệu, thưởng bất ngờ
  lib/reminders.dart, lib/reminder_backend_web.dart, lib/reminder_backend_native.dart   nhắc học
  .github/workflows/build-ios.yml                                    build .ipa chưa ký

FILE ĐÈ (nội dung)
  ai_service.dart        che API key trong lỗi
  home_screen.dart       boss không bốc lab, đồng bộ nhắc học, withValues
  game_session_screen.dart, tabs.dart, bag.dart, i18n.dart, settings_screen.dart   tính năng v10b / v10c
  widgets.dart           màn đẩy lên giữ bề rộng tối đa 720 px trên laptop (slideUpRoute)
  learn_tab.dart, practice_tab.dart, library_screen.dart, streak_screen.dart, titles.dart,
  exam_screen.dart, duck.dart, stats_chart.dart, backup_service.dart, question_extras.dart,
  ai_chat.dart, i18n_vi.dart     dọn cảnh báo flutter analyze (withOpacity, activeColor, onPopInvoked, const, null-aware...)
  pubspec.yaml           + flutter_local_notifications ^19.0.0, timezone ^0.10.0
  android/app/src/main/AndroidManifest.xml, android/app/build.gradle.kts    quyền thông báo, desugaring

XÓA
  test/widget_test.dart   ->  git rm test/widget_test.dart
