// widget_theme.dart  (FILE MỚI)  Báo cho widget Android biết chế độ màu (auto|light|dark) ngay khi đổi Appearance.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Future<void> pushWidgetTheme(String theme) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await const MethodChannel('duckpacket/widget').invokeMethod('update', {'theme': theme});
  } catch (_) {}
}
