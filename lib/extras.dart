import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const kGoalOptions = [10, 20, 50];

String _dk(DateTime d) => '${d.year}-${d.month}-${d.day}';

class ExtrasState {
  final int goal; // daily XP goal
  final int todayXp;
  const ExtrasState({this.goal = 20, this.todayXp = 0});
  bool get goalDone => todayXp >= goal;
  ExtrasState copy({int? goal, int? todayXp}) => ExtrasState(goal: goal ?? this.goal, todayXp: todayXp ?? this.todayXp);
}

/// Daily goal. Uses its own keys (prefix "x_") in the existing 'stats' Hive box.
class ExtrasNotifier extends Notifier<ExtrasState> {
  Box get _box => Hive.box('stats');

  @override
  ExtrasState build() {
    final b = _box;
    final today = _dk(DateTime.now());
    final xpDay = b.get('x_xpDay') as String?;
    return ExtrasState(
      goal: (b.get('x_goal') as int?) ?? 20,
      todayXp: xpDay == today ? ((b.get('x_xpToday') as int?) ?? 0) : 0,
    );
  }

  void setGoal(int g) {
    _box.put('x_goal', g);
    state = state.copy(goal: g);
  }

  void addXp(int xp) {
    final today = _dk(DateTime.now());
    final base = _box.get('x_xpDay') == today ? state.todayXp : 0;
    final v = base + xp;
    _box.put('x_xpDay', today);
    _box.put('x_xpToday', v);
    state = state.copy(todayXp: v);
  }

  void reset() {
    // x_chests / x_heartAt are leftovers of removed features
    for (final k in ['x_xpDay', 'x_xpToday', 'x_chests', 'x_heartAt']) {
      _box.delete(k);
    }
    state = ExtrasState(goal: state.goal);
  }
}

final extrasProvider = NotifierProvider<ExtrasNotifier, ExtrasState>(ExtrasNotifier.new);
