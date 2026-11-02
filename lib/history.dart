import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'study.dart' show dayNum;

class HistState {
  /// day number -> [xp, answered, correct]
  final Map<int, List<int>> days;
  const HistState([this.days = const {}]);
}

/// Per-day history for the progress chart. Hive key: x_hist. Starts empty (past days are unknown).
class HistoryNotifier extends Notifier<HistState> {
  Box get _box => Hive.box('stats');

  @override
  HistState build() {
    final out = <int, List<int>>{};
    try {
      final raw = _box.get('x_hist');
      if (raw is String && raw.isNotEmpty) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) {
          final l = (v as List).map((e) => (e as num).toInt()).toList();
          if (l.length == 3) out[int.parse(k)] = l;
        });
      }
    } catch (_) {}
    return HistState(out);
  }

  void _upd(void Function(List<int>) f) {
    final d = dayNum();
    final m = Map<int, List<int>>.from(state.days);
    final row = [...(m[d] ?? [0, 0, 0])];
    f(row);
    m[d] = row;
    state = HistState(m);
    _box.put('x_hist', jsonEncode(m.map((k, v) => MapEntry('$k', v))));
  }

  void addXp(int xp) => _upd((r) => r[0] += xp);

  /// First attempt of a question only.
  void addAnswer(bool ok) => _upd((r) {
        r[1] += 1;
        if (ok) r[2] += 1;
      });

  void reset() {
    _box.delete('x_hist');
    state = const HistState();
  }
}

final historyProvider = NotifierProvider<HistoryNotifier, HistState>(HistoryNotifier.new);
