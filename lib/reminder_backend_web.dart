// reminder_backend_web.dart  (FILE MỚI)  Thông báo trên web: Notification API của trình duyệt.
// Chỉ hiện khi tab DuckPacket còn mở và bạn đã cho phép thông báo.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ReminderBackend {
  /// false = hệ điều hành KHÔNG hẹn giờ được khi app đóng; app tự kiểm tra giờ khi đang mở.
  static bool get canSchedule => false;

  static Future<void> init() async {}

  static Future<bool> requestPermission() async {
    try {
      if (!html.Notification.supported) return false;
      final p = await html.Notification.requestPermission();
      return p == 'granted';
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancelAll() async {}

  static Future<void> schedule(int id, DateTime local, String title, String body) async {}

  static Future<void> showNow(String title, String body) async {
    try {
      if (html.Notification.supported && html.Notification.permission == 'granted') {
        html.Notification(title, body: body);
      }
    } catch (_) {}
  }
}
