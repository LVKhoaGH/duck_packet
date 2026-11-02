import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'study.dart' show dayNum;

String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class UserStats {
  final int hearts, streak, xp;
  final Set<String> completed, days;
  final String lastDay;
  const UserStats({
    this.hearts = 5,
    this.streak = 0,
    this.xp = 0,
    this.completed = const {},
    this.days = const {},
    this.lastDay = '',
  });
  bool get practicedToday => lastDay == dayKey(DateTime.now());
  UserStats copyWith({int? hearts, int? streak, int? xp, Set<String>? completed, Set<String>? days, String? lastDay}) => UserStats(
        hearts: hearts ?? this.hearts,
        streak: streak ?? this.streak,
        xp: xp ?? this.xp,
        completed: completed ?? this.completed,
        days: days ?? this.days,
        lastDay: lastDay ?? this.lastDay,
      );
}

class _Fz {
  final int streak;
  final String last;
  _Fz(this.streak, this.last);
}

class StatsNotifier extends Notifier<UserStats> {
  Box get _box => Hive.box('stats');

  @override
  UserStats build() {
    final last = _box.get('lastDay', defaultValue: '') as String;
    final z = _applyFreeze(last, _box.get('streak', defaultValue: 0) as int, DateTime.now());
    return UserStats(
      hearts: _box.get('hearts', defaultValue: 5),
      streak: z.streak,
      xp: _box.get('xp', defaultValue: 0),
      lastDay: z.last,
      completed: Set<String>.from(_box.get('completed', defaultValue: <String>[])),
      days: Set<String>.from(_box.get('days', defaultValue: <String>[])),
    );
  }

  /// Missed days are covered by Streak Freezes (stored in 'x_freeze'), one freeze per missed day.
  /// Not enough freezes -> the streak goes back to 0. Covered days make lastDay "yesterday".
  _Fz _applyFreeze(String last, int streak, DateTime now) {
    if (last.isEmpty) return _Fz(0, last);
    if (last == dayKey(now)) return _Fz(streak, last);
    int gap;
    try {
      gap = dayNum(now) - dayNum(DateTime.parse(last)) - 1;
    } catch (_) {
      return _Fz(0, last);
    }
    if (gap <= 0) return _Fz(streak, last); // practiced yesterday
    final fz = (_box.get('x_freeze', defaultValue: 0) as num).toInt();
    if (streak > 0 && fz >= gap) {
      final covered = dayKey(now.subtract(const Duration(days: 1)));
      _box.put('x_freeze', fz - gap);
      _box.put('x_freezeUsed', ((_box.get('x_freezeUsed', defaultValue: 0) as num).toInt()) + gap);
      _box.put('lastDay', covered);
      return _Fz(streak, covered);
    }
    return _Fz(0, last);
  }

  void _save() {
    _box.put('hearts', state.hearts);
    _box.put('streak', state.streak);
    _box.put('xp', state.xp);
    _box.put('lastDay', state.lastDay);
    _box.put('completed', state.completed.toList());
    _box.put('days', state.days.toList());
  }

  void loseHeart() {
    if (state.hearts > 0) state = state.copyWith(hearts: state.hearts - 1);
    _save();
  }

  void gainHeart() {
    if (state.hearts < 5) state = state.copyWith(hearts: state.hearts + 1);
    _save();
  }

  void refillHearts() {
    state = state.copyWith(hearts: 5);
    _save();
  }

  /// Daily streak: +1 on the first lesson of each consecutive day.
  void completeNode(String id, {int xp = 10, bool markNode = true}) {
    final now = DateTime.now();
    final today = dayKey(now);
    final yesterday = dayKey(now.subtract(const Duration(days: 1)));
    var s = state.streak;
    if (state.lastDay != today) {
      final z = _applyFreeze(state.lastDay, state.streak, now);
      s = z.last == yesterday ? z.streak + 1 : 1;
    }
    state = state.copyWith(
      streak: s,
      xp: state.xp + xp,
      lastDay: today,
      days: {...state.days, today},
      completed: markNode ? {...state.completed, id} : state.completed,
    );
    _save();
  }

  /// XP without touching the streak (chest rewards).
  void addXp(int xp) {
    state = state.copyWith(xp: state.xp + xp);
    _save();
  }

  void reset() {
    state = const UserStats();
    _save();
  }
}

final statsProvider = NotifierProvider<StatsNotifier, UserStats>(StatsNotifier.new);
