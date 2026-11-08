// widget_sync.dart  (ĐÈ BẢN CŨ)  Gửi dữ liệu sang 5 widget Android qua kênh "duckpacket/widget".
// Trên web / Windows không làm gì (chỉ lưu ngày thi).
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'library.dart' show courseProvider;
import 'providers.dart';
import 'study.dart';

const MethodChannel _ch = MethodChannel('duckpacket/widget');

/// Ngày thi dạng yyyy-MM-dd ('' = chưa đặt). Lưu trong box 'stats' khóa x_examDate (Backup tự gom).
final examDateProvider = StateProvider<String>((ref) => '${Hive.box('stats').get('x_examDate', defaultValue: '')}');

Future<void> setExamDate(WidgetRef ref, String v) async {
  final box = Hive.box('stats');
  if (v.isEmpty) {
    await box.delete('x_examDate');
  } else {
    await box.put('x_examDate', v);
  }
  ref.read(examDateProvider.notifier).state = v;
  await syncHomeWidget(ref);
}

String _cut(String s, int n) => s.length <= n ? s : '${s.substring(0, n - 1)}…';

Future<void> syncHomeWidget(WidgetRef ref) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final s = ref.read(statsProvider);
    final study = ref.read(studyProvider);
    final course = ref.read(courseProvider).valueOrNull;
    final box = Hive.box('stats');

    final days = s.days.toList()..sort();
    final recent = days.length > 21 ? days.sublist(days.length - 21) : days;
    final freezes = (box.get('x_freeze', defaultValue: 0) as num).toInt();

    final gloss = <Map<String, String>>[];
    if (course != null) {
      for (final g in course.glossary.take(300)) {
        gloss.add({'t': _cut(g.term, 40), 'd': _cut(g.def, 160), 'c': _cut(g.cmd, 60), 'g': _cut(g.tag, 16)});
      }
    }

    final due = <int>[];
    var wrong = 0;
    for (final r in study.recs.values) {
      if (r.enrolled) due.add(r.due);
      if (r.wrong) wrong++;
    }

    String weak = '';
    if (course != null) {
      DomainStat? w;
      for (final d in domainStats(course)) {
        if (d.attempted(study.recs) == 0) continue;
        if (w == null || d.mastery(study.recs) < w.mastery(study.recs)) w = d;
      }
      weak = w?.label ?? '';
    }

    await _ch.invokeMethod('update', {
      'streak': s.streak,
      'lastDay': s.lastDay,
      'freezes': freezes,
      'days': recent.join(','),
      'glossary': jsonEncode(gloss),
      'dueDays': due.join(','),
      'wrong': wrong,
      'exam': ref.read(examDateProvider),
      'weak': weak,
    });
  } catch (_) {
    // widget chưa được thêm hoặc kênh chưa có: bỏ qua
  }
}
