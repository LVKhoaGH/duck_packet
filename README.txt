DuckPacket v10b + v10c  (giải nén đè vào duck_packet/, CHƯA biên dịch)

SAU KHI ĐÈ: chạy `flutter pub get` (có thêm 2 package), rồi dừng hẳn app và chạy lại.

FILE MỚI
  lib/quests.dart, lib/quests_screen.dart, lib/i18n_vi_meta.dart     nhiệm vụ ngày, huy hiệu, thưởng bất ngờ
  lib/reminders.dart                                                 nhắc học (logic + lịch)
  lib/reminder_backend_web.dart                                      thông báo trình duyệt
  lib/reminder_backend_native.dart                                   Android / iOS (hẹn giờ thật), Windows (toast PowerShell)
  .github/workflows/build-ios.yml                                    build .ipa chưa ký

FILE ĐÈ
  lib/game_session_screen.dart, lib/tabs.dart, lib/bag.dart, lib/i18n.dart
  lib/settings_screen.dart    thêm mục "Study reminders"
  lib/home_screen.dart        boss không bốc lab + đồng bộ nhắc học
  lib/ai_service.dart         che API key trong lỗi
  pubspec.yaml                + flutter_local_notifications ^19.0.0, timezone ^0.10.0
  android/app/src/main/AndroidManifest.xml    quyền thông báo + receiver
  android/app/build.gradle.kts                bật desugaring (plugin thông báo cần)

XÓA
  test/widget_test.dart   (git rm test/widget_test.dart)
