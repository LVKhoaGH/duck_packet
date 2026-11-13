DuckPacket v11  = TỔNG HỢP v10a..v10e + DARK MODE (giải nén đè vào duck_packet/, CHƯA biên dịch)
Chỉ cần zip này. Sau khi đè: flutter pub get, rồi DỪNG HẲN app và chạy lại.

DARK MODE (xám than)
  Settings -> Appearance: Auto (theo hệ thống) / Light / Dark. Lưu ở Hive 'x_theme'.
  lib/theme.dart      AppColors: màu trung tính (ink, line, surface, soft, tint, locked, sub...) là getter theo AppColors.dark;
                      màu thương hiệu (primary, success, error, streak) giữ nguyên; buildTheme(dark: true); rebuildAllElements()
  lib/main.dart       themeMode + đặt AppColors.dark trước khi dựng UI; đổi chế độ giữ nguyên trạng thái màn hình
  lib/settings.dart   thêm trường theme
  lib/settings_screen.dart   mục Appearance
  Mọi file giao diện (home, learn, practice, tabs, game session, exam, library, glossary, bag, titles, streak,
  quests, stats chart, question extras, lab, ai_chat, duck wardrobe, tracks...) đã đổi màu cứng
  (Colors.white nền, Colors.black45..., F7F7F7, AFAFAF, ...) sang AppColors theo chế độ. Chế độ Light giữ đúng giao diện cũ.

CÒN LẠI KHÔNG ĐỔI: widget màn hình Android (sẽ làm khi có file Kotlin + layout).
