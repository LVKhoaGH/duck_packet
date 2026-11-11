// reminder_backend_native.dart  (FILE MỚI)
//  Android / iOS : hẹn giờ thật bằng flutter_local_notifications (nhắc được cả khi app đóng).
//  Windows       : toast qua PowerShell khi app đang chạy (không cần cài gì thêm).
import 'dart:io' show Platform, Process;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class ReminderBackend {
  static final FlutterLocalNotificationsPlugin _p = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static bool get _mobile => Platform.isAndroid || Platform.isIOS;

  /// true = hệ điều hành tự bắn thông báo đúng giờ, kể cả khi app đóng.
  static bool get canSchedule => _mobile;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'duck_study',
      'Study reminders',
      channelDescription: 'Daily study reminders from your duck',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> init() async {
    if (_ready || !_mobile) return;
    try {
      await _p.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ));
      _ready = true;
    } catch (_) {}
  }

  static Future<bool> requestPermission() async {
    if (!_mobile) return true;
    await init();
    try {
      if (Platform.isAndroid) {
        final a = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final ok = await a?.requestNotificationsPermission();
        return ok ?? true;
      }
      final i = _p.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final ok = await i?.requestPermissions(alert: true, badge: true, sound: true);
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancelAll() async {
    if (!_mobile) return;
    await init();
    try {
      await _p.cancelAll();
    } catch (_) {}
  }

  /// Hẹn một thông báo vào giờ ĐỊA PHƯƠNG [local] (đổi sang UTC nên không cần cơ sở dữ liệu múi giờ).
  static Future<void> schedule(int id, DateTime local, String title, String body) async {
    if (!_mobile) return;
    await init();
    final u = local.toUtc();
    final when = tz.TZDateTime.utc(u.year, u.month, u.day, u.hour, u.minute);
    try {
      await _p.zonedSchedule(
        id,
        title,
        body,
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  static Future<void> showNow(String title, String body) async {
    if (_mobile) {
      await init();
      try {
        await _p.show(900, title, body, _details);
      } catch (_) {}
      return;
    }
    if (Platform.isWindows) {
      String q(String s) => s.replaceAll("'", "''");
      final script = "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null;"
          "\$t = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02);"
          "\$n = \$t.GetElementsByTagName('text');"
          "\$n.Item(0).AppendChild(\$t.CreateTextNode('${q(title)}')) | Out-Null;"
          "\$n.Item(1).AppendChild(\$t.CreateTextNode('${q(body)}')) | Out-Null;"
          "\$id = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\\WindowsPowerShell\\v1.0\\powershell.exe';"
          "[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier(\$id).Show([Windows.UI.Notifications.ToastNotification]::new(\$t))";
      try {
        await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-Command', script]);
      } catch (_) {}
    }
  }
}
