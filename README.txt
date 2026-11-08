DUCKPACKET v4  (AI không có Flutter SDK / Android SDK. Chưa biên dịch. Dán log thật nếu lỗi.)
Giải nén ĐÈ lên duck_packet/ (sau khi đã đè v3). Gồm:
  lib/study.dart            luật mở khóa mới
  lib/home_screen.dart      Map mở bài đầu mọi chương + gửi dữ liệu sang widget
  lib/duck_mood.dart        công thức đổi mặt vịt đơn giản (để widget dùng chung)
  lib/widget_sync.dart      MỚI
  android/app/src/main/AndroidManifest.xml                         ĐÈ (thêm receiver widget)
  android/app/src/main/kotlin/com/example/duck_packet/MainActivity.kt          ĐÈ
  android/app/src/main/kotlin/com/example/duck_packet/DuckWidgetProvider.kt    MỚI
  android/app/src/main/res/layout|xml|drawable|drawable-nodpi/...             MỚI

Thêm widget: giữ lâu màn hình chính điện thoại -> Widgets -> DuckPacket.

git add .
git commit -m "Unlock first stage of every chapter, Android home widget"
git push origin main
