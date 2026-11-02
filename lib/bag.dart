import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'providers.dart';

const kMaxFreeze = 3; // Streak Freezes you can hold
const kBoostLessons = 3; // lessons covered by one XP x2
const kChestXp = 25;

class BagState {
  final int freeze, xp2, boost; // boost = lessons left with XP x2 active
  final Set<String> chests; // chapter ids whose chest was opened
  const BagState({this.freeze = 0, this.xp2 = 0, this.boost = 0, this.chests = const {}});
}

class ChestReward {
  final int xp;
  final List<String> items; // 'freeze' | 'xp2'
  ChestReward(this.xp, this.items);
}

/// Inventory. Hive keys (box 'stats'): x_freeze, x_xp2, x_boost, x_chestOpen.
/// x_freeze is also spent by StatsNotifier when a day is missed, so this rebuilds when stats change.
class BagNotifier extends Notifier<BagState> {
  Box get _box => Hive.box('stats');
  int _i(String k) => (_box.get(k, defaultValue: 0) as num).toInt();

  @override
  BagState build() {
    ref.watch(statsProvider);
    return BagState(
      freeze: _i('x_freeze'),
      xp2: _i('x_xp2'),
      boost: _i('x_boost'),
      chests: ((_box.get('x_chestOpen') as List?) ?? const []).map((e) => '$e').toSet(),
    );
  }

  void _save() {
    _box.put('x_freeze', state.freeze);
    _box.put('x_xp2', state.xp2);
    _box.put('x_boost', state.boost);
    _box.put('x_chestOpen', state.chests.toList());
  }

  BagState _with({int? freeze, int? xp2, int? boost, Set<String>? chests}) => BagState(
        freeze: freeze ?? state.freeze,
        xp2: xp2 ?? state.xp2,
        boost: boost ?? state.boost,
        chests: chests ?? state.chests,
      );

  /// Spend one XP x2 item: the next [kBoostLessons] lessons give double XP.
  void useXp2() {
    if (state.xp2 <= 0) return;
    state = _with(xp2: state.xp2 - 1, boost: state.boost + kBoostLessons);
    _save();
  }

  /// Called when a lesson finishes. Returns 2 while a boost is active (and uses up one lesson of it), else 1.
  int consumeBoost() {
    if (state.boost <= 0) return 1;
    state = _with(boost: state.boost - 1);
    _save();
    return 2;
  }

  /// Opens the chest of a chapter (once). Returns null if it was already opened.
  ChestReward? openChest(String chapterId) {
    if (state.chests.contains(chapterId)) return null;
    final rnd = Random();
    final items = <String>[];
    var freeze = state.freeze, xp2 = state.xp2;
    void give(String id) {
      if (id == 'freeze' && freeze < kMaxFreeze) {
        freeze++;
        items.add('freeze');
      } else {
        xp2++;
        items.add('xp2');
      }
    }

    give(rnd.nextInt(100) < 45 ? 'freeze' : 'xp2'); // a full freeze slot turns into an XP x2
    if (rnd.nextInt(100) < 25) give('xp2'); // lucky bonus
    state = _with(freeze: freeze, xp2: xp2, chests: {...state.chests, chapterId});
    _save();
    return ChestReward(kChestXp, items);
  }

  void reset() {
    for (final k in ['x_freeze', 'x_xp2', 'x_boost', 'x_chestOpen', 'x_freezeUsed']) {
      _box.delete(k);
    }
    state = const BagState();
  }
}

final bagProvider = NotifierProvider<BagNotifier, BagState>(BagNotifier.new);
