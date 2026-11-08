DUCKPACKET v3  (AI không có Flutter SDK. Code CHƯA biên dịch. Dừng hẳn app rồi chạy lại, dán log thật nếu lỗi.)

GIẢI NÉN ĐÈ vào duck_packet/ (giữ nguyên thư mục):
  .github/workflows/build-apk.yml   ĐÈ  (sửa lỗi build APK: ép compileSdk 36)
  pubspec.yaml                      giống bản trước (đã có http)
  lib/ai_service.dart               ĐÈ  nhiều key, nhiều nhà cung cấp, xoay vòng
  lib/ai_chat.dart                  ĐÈ  quản lý key + chat
  lib/game_tab.dart                 MỚI tab Game (Coming soon)
  lib/home_screen.dart              ĐÈ  5 tab: Learn, Map, Practice, Game, Profile
  lib/question_extras.dart          MỚI 3 dạng bài: show_output, route_predict, topology_drag
  lib/models.dart                   ĐÈ  (thêm raw; correct_answer nhận cả số)
  lib/library.dart                  ĐÈ  (validator 3 dạng mới)
  lib/game_session_screen.dart      ĐÈ
  lib/exam_screen.dart              ĐÈ  thi thử hỗ trợ multi_select, lab (lab lên đầu), 3 dạng mới
  lib/settings_screen.dart          giống bản trước
  lib/sample_course.dart            ĐÈ  JSON mẫu đủ 10 dạng

Nhớ đây là bản vá trên file bạn upload gần nhất. Sửa tay sau đó sẽ bị ghi đè.

git add .
git commit -m "v3: 5 tabs, 3 new question types, exam support, multi-key AI, APK fix"
git push origin main
