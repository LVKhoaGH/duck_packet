// widget_sync.dart  (FILE MỚI)  Gửi streak + các ngày đã học sang widget Android (kênh "duckpacket/widget").
// Trên web / Windows không làm gì.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'providers.dart';

const MethodChannel _ch = MethodChannel('duckpacket/widget');

Future<void> syncHomeWidget(UserStats s) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final freezes = (Hive.box('stats').get('x_freeze', defaultValue: 0) as num).toInt();
    final days = s.days.toList()..sort();
    final recent = days.length > 21 ? days.sublist(days.length - 21) : days;
    await _ch.invokeMethod('update', {
      'streak': s.streak,
      'lastDay': s.lastDay,
      'freezes': freezes,
      'days': recent.join(','),
    });
  } catch (_) {
    // widget chưa được thêm hoặc kênh chưa có: bỏ qua
  }
}
