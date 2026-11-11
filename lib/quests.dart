// quests.dart  (FILE MỚI)  Nhiệm vụ hằng ngày + huy hiệu + phần thưởng bất ngờ.
// Dữ liệu nằm trong box 'stats', khóa 'x_meta' (JSON) nên Backup/Restore tự gom.
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'bag.dart';
import 'duck.dart';
import 'extras.dart';
import 'history.dart';
import 'i18n.dart' show AppLang;
import 'providers.dart';
import 'study.dart';
import 'theme.dart';

const int kQuestBonusXp = 30; // xong cả 3 nhiệm vụ trong ngày
const int kLuckyMaxPerDay = 2;

// ───────────────────────── nhiệm vụ ─────────────────────────
class QuestDef {
  final String id, kind, en, vi;
  final int target, xp;
  final IconData icon;
  const QuestDef(this.id, this.kind, this.target, this.xp, this.en, this.vi, this.icon);
  String get text => (AppLang.vi ? vi : en).replaceAll('{n}', '$target');
}

const List<QuestDef> kQuestPool = [
  QuestDef('l2', 'lessons', 2, 15, 'Finish {n} lessons', 'Hoàn thành {n} bài', Icons.menu_book_rounded),
  QuestDef('l3', 'lessons', 3, 25, 'Finish {n} lessons', 'Hoàn thành {n} bài', Icons.menu_book_rounded),
  QuestDef('a20', 'answers', 20, 15, 'Answer {n} questions', 'Trả lời {n} câu hỏi', Icons.help_outline_rounded),
  QuestDef('a40', 'answers', 40, 25, 'Answer {n} questions', 'Trả lời {n} câu hỏi', Icons.help_outline_rounded),
  QuestDef('c15', 'correct', 15, 15, 'Get {n} answers right', 'Trả lời đúng {n} câu', Icons.check_circle_outline_rounded),
  QuestDef('p1', 'perfect', 1, 20, 'Finish a lesson without a mistake', 'Hoàn thành một bài không sai câu nào', Icons.star_rounded),
  QuestDef('f5', 'fixed', 5, 20, 'Fix {n} mistakes in Review or Mistakes', 'Sửa {n} câu sai trong Ôn tập hoặc Câu sai', Icons.build_rounded),
  QuestDef('s1', 'fast', 1, 20, 'Finish a lesson in under 90 seconds', 'Hoàn thành một bài dưới 90 giây', Icons.bolt_rounded),
  QuestDef('x30', 'xp', 30, 15, 'Earn {n} XP', 'Kiếm {n} XP', Icons.stars_rounded),
  QuestDef('r1', 'review', 1, 15, 'Do a Review or Mistakes session', 'Làm một phiên Ôn tập hoặc Câu sai', Icons.event_repeat_rounded),
];

/// 3 nhiệm vụ của một ngày (cùng một ngày = cùng bộ nhiệm vụ). Nhiệm vụ đầu luôn dễ.
List<QuestDef> questsFor(int day) {
  final rnd = Random(day * 7919 + 13);
  final easy = [kQuestPool[0], kQuestPool[2], kQuestPool[8]];
  final out = <QuestDef>[easy[rnd.nextInt(easy.length)]];
  final kinds = <String>{out.first.kind};
  final rest = List<QuestDef>.of(kQuestPool)..shuffle(rnd);
  for (final q in rest) {
    if (out.length >= 3) break;
    if (kinds.contains(q.kind)) continue;
    kinds.add(q.kind);
    out.add(q);
  }
  return out;
}

// ───────────────────────── huy hiệu ─────────────────────────
class AchDef {
  final String id, group, counter, en, vi, dEn, dVi;
  final int goal, xp;
  final IconData icon;
  final Color color;
  const AchDef(this.id, this.group, this.icon, this.color, this.counter, this.goal, this.xp, this.en, this.vi, this.dEn, this.dVi);
  String get name => AppLang.vi ? vi : en;
  String get desc => AppLang.vi ? dVi : dEn;
}

const Color _purple = Color(0xFF9B6BFF);

const List<MapEntry<String, String>> kAchGroups = [
  MapEntry('learn', 'Learning'),
  MapEntry('accuracy', 'Accuracy'),
  MapEntry('speed', 'Speed'),
  MapEntry('grit', 'Grit'),
  MapEntry('streak', 'Streaks'),
  MapEntry('boss', 'Bosses'),
  MapEntry('lab', 'Labs'),
  MapEntry('daily', 'Daily quests'),
  MapEntry('luck', 'Luck'),
  MapEntry('collect', 'Collection'),
];

const List<AchDef> kAch = [
  // Learning
  AchDef('first_win', 'learn', Icons.flag_rounded, AppColors.success, 'lessons', 1, 10, 'First Steps', 'Bước Đầu', 'Finish your first lesson', 'Hoàn thành bài học đầu tiên'),
  AchDef('lessons_10', 'learn', Icons.local_fire_department_rounded, AppColors.streak, 'lessons', 10, 25, 'Warming Up', 'Khởi Động', 'Finish 10 lessons', 'Hoàn thành 10 bài'),
  AchDef('lessons_50', 'learn', Icons.fitness_center_rounded, AppColors.primary, 'lessons', 50, 40, 'Grinder', 'Chăm Chỉ', 'Finish 50 lessons', 'Hoàn thành 50 bài'),
  AchDef('lessons_200', 'learn', Icons.precision_manufacturing_rounded, _purple, 'lessons', 200, 100, 'Study Machine', 'Cỗ Máy Học Tập', 'Finish 200 lessons', 'Hoàn thành 200 bài'),
  AchDef('answers_100', 'learn', Icons.quiz_rounded, AppColors.secondary, 'answers', 100, 25, 'Hundred Club', 'Câu Lạc Bộ 100', 'Answer 100 questions', 'Trả lời 100 câu hỏi'),
  AchDef('answers_500', 'learn', Icons.psychology_rounded, AppColors.primary, 'answers', 500, 60, 'Quiz Master', 'Bậc Thầy Trắc Nghiệm', 'Answer 500 questions', 'Trả lời 500 câu hỏi'),
  AchDef('answers_2000', 'learn', Icons.auto_stories_rounded, _purple, 'answers', 2000, 150, 'Walking Encyclopedia', 'Từ Điển Sống', 'Answer 2000 questions', 'Trả lời 2000 câu hỏi'),
  AchDef('day_100', 'learn', Icons.directions_run_rounded, AppColors.error, 'dayAnswers', 100, 60, 'Marathon', 'Marathon', 'Answer 100 questions in one day', 'Trả lời 100 câu trong một ngày'),
  // Accuracy
  AchDef('perfect_1', 'accuracy', Icons.star_rounded, AppColors.streak, 'perfect', 1, 20, 'Flawless', 'Hoàn Hảo', 'Finish a lesson without a single mistake', 'Hoàn thành một bài không sai câu nào'),
  AchDef('perfect_10', 'accuracy', Icons.stars_rounded, AppColors.streak, 'perfect', 10, 50, 'Perfectionist', 'Cầu Toàn', 'Finish 10 flawless lessons', 'Hoàn thành 10 bài không sai câu nào'),
  AchDef('perfect_50', 'accuracy', Icons.diamond_rounded, AppColors.primary, 'perfect', 50, 120, 'Untouchable', 'Bất Khả Xâm Phạm', 'Finish 50 flawless lessons', 'Hoàn thành 50 bài không sai câu nào'),
  AchDef('combo_10', 'accuracy', Icons.whatshot_rounded, AppColors.error, 'combo', 10, 30, 'On Fire', 'Bùng Cháy', 'Get 10 correct answers in a row', 'Trả lời đúng liên tiếp 10 câu'),
  AchDef('combo_20', 'accuracy', Icons.rocket_launch_rounded, AppColors.error, 'combo', 20, 70, 'Unstoppable', 'Không Thể Cản', 'Get 20 correct answers in a row', 'Trả lời đúng liên tiếp 20 câu'),
  // Speed
  AchDef('fast_1', 'speed', Icons.bolt_rounded, AppColors.streak, 'fast', 1, 25, 'Lightning', 'Tia Chớp', 'Finish a lesson (5+ questions) in under 90 seconds with 80%+ accuracy', 'Hoàn thành một bài (5+ câu) dưới 90 giây với độ chính xác 80%+'),
  AchDef('fast_10', 'speed', Icons.speed_rounded, AppColors.error, 'fast', 10, 80, 'Speed Demon', 'Quỷ Tốc Độ', 'Do that 10 times', 'Làm được điều đó 10 lần'),
  AchDef('fast_50', 'speed', Icons.hourglass_bottom_rounded, _purple, 'fast', 50, 150, 'Time Lord', 'Chúa Tể Thời Gian', 'Do that 50 times', 'Làm được điều đó 50 lần'),
  // Grit
  AchDef('stubborn_3', 'grit', Icons.sentiment_neutral_rounded, AppColors.lockedShadow, 'wrongMax', 3, 15, 'Stubborn', 'Cứng Đầu', 'Get the same question wrong 3 times', 'Sai cùng một câu 3 lần'),
  AchDef('stubborn_5', 'grit', Icons.sentiment_dissatisfied_rounded, AppColors.streak, 'wrongMax', 5, 25, 'Hard Head', 'Đầu Đá', 'Get the same question wrong 5 times', 'Sai cùng một câu 5 lần'),
  AchDef('stubborn_10', 'grit', Icons.sentiment_very_dissatisfied_rounded, AppColors.error, 'wrongMax', 10, 50, 'Never Give Up', 'Không Bỏ Cuộc', 'Get the same question wrong 10 times and keep trying', 'Sai cùng một câu 10 lần mà vẫn tiếp tục'),
  AchDef('phoenix', 'grit', Icons.cached_rounded, AppColors.error, 'phoenix', 1, 40, 'Phoenix', 'Phượng Hoàng', 'Answer correctly a question you got wrong 3+ times before', 'Trả lời đúng một câu từng sai 3 lần trở lên'),
  AchDef('fixer_25', 'grit', Icons.build_rounded, AppColors.secondary, 'fixed', 25, 40, 'Bug Squasher', 'Diệt Lỗi', 'Fix 25 mistakes in Review or Mistakes', 'Sửa 25 câu sai trong Ôn tập hoặc Câu sai'),
  AchDef('fixer_100', 'grit', Icons.manage_search_rounded, AppColors.primary, 'fixed', 100, 100, 'Mistake Hunter', 'Thợ Săn Lỗi', 'Fix 100 mistakes', 'Sửa 100 câu sai'),
  AchDef('night', 'grit', Icons.nightlight_round, _purple, 'night', 1, 20, 'Night Owl', 'Cú Đêm', 'Finish a lesson between 23:00 and 04:00', 'Hoàn thành một bài trong khoảng 23:00 đến 04:00'),
  AchDef('early', 'grit', Icons.wb_sunny_rounded, AppColors.streak, 'early', 1, 20, 'Early Bird', 'Chim Sớm', 'Finish a lesson between 04:00 and 07:00', 'Hoàn thành một bài trong khoảng 04:00 đến 07:00'),
  // Streaks
  AchDef('streak_3', 'streak', Icons.local_fire_department_rounded, AppColors.streak, 'streak', 3, 20, 'Warm Start', 'Khởi Đầu Ấm', 'Reach a 3-day streak', 'Đạt chuỗi 3 ngày'),
  AchDef('streak_7', 'streak', Icons.local_fire_department_rounded, AppColors.error, 'streak', 7, 40, 'On a Roll', 'Đang Đà', 'Reach a 7-day streak', 'Đạt chuỗi 7 ngày'),
  AchDef('streak_30', 'streak', Icons.local_fire_department_rounded, AppColors.error, 'streak', 30, 120, 'Unbreakable', 'Không Gì Phá Nổi', 'Reach a 30-day streak', 'Đạt chuỗi 30 ngày'),
  AchDef('streak_100', 'streak', Icons.workspace_premium_rounded, _purple, 'streak', 100, 300, 'Legend', 'Huyền Thoại', 'Reach a 100-day streak', 'Đạt chuỗi 100 ngày'),
  // Bosses
  AchDef('boss_1', 'boss', Icons.shield_rounded, AppColors.error, 'bossWins', 1, 30, 'Boss Slayer', 'Kẻ Diệt Trùm', 'Beat your first boss', 'Hạ trùm đầu tiên'),
  AchDef('boss_5', 'boss', Icons.military_tech_rounded, AppColors.error, 'bossWins', 5, 80, 'Boss Hunter', 'Thợ Săn Trùm', 'Beat 5 bosses', 'Hạ 5 trùm'),
  AchDef('boss_flawless', 'boss', Icons.emoji_events_rounded, AppColors.streak, 'bossFlawless', 1, 60, 'Flawless Victory', 'Chiến Thắng Tuyệt Đối', 'Beat a boss with 100% accuracy', 'Hạ trùm với độ chính xác 100%'),
  AchDef('revenge', 'boss', Icons.replay_rounded, AppColors.secondary, 'revenge', 1, 40, 'Revenge', 'Báo Thù', 'Beat a boss that you lost to before', 'Hạ một con trùm từng thua trước đó'),
  // Labs
  AchDef('lab_1', 'lab', Icons.terminal_rounded, AppColors.terminalBg, 'labs', 1, 30, 'Console Cowboy', 'Cao Bồi Console', 'Pass your first lab', 'Vượt qua lab đầu tiên'),
  AchDef('lab_10', 'lab', Icons.settings_ethernet_rounded, AppColors.primary, 'labs', 10, 100, 'Network Wizard', 'Phù Thủy Mạng', 'Pass 10 labs', 'Vượt qua 10 lab'),
  // Daily quests
  AchDef('quest_1', 'daily', Icons.task_alt_rounded, AppColors.success, 'claims', 1, 15, 'Daily Duty', 'Nhiệm Vụ Đầu Tiên', 'Claim your first quest reward', 'Nhận phần thưởng nhiệm vụ đầu tiên'),
  AchDef('quest_25', 'daily', Icons.checklist_rounded, AppColors.success, 'claims', 25, 80, 'Quest Hero', 'Anh Hùng Nhiệm Vụ', 'Claim 25 quest rewards', 'Nhận 25 phần thưởng nhiệm vụ'),
  AchDef('quest_all', 'daily', Icons.looks_3_rounded, AppColors.primary, 'qdays', 1, 30, 'Triple Threat', 'Bộ Ba', 'Complete all 3 daily quests in one day', 'Hoàn thành cả 3 nhiệm vụ trong một ngày'),
  AchDef('quest_days_7', 'daily', Icons.event_available_rounded, _purple, 'qdays', 7, 100, 'Quest Streak', 'Chuỗi Nhiệm Vụ', 'Complete all quests on 7 different days', 'Hoàn thành đủ nhiệm vụ trong 7 ngày khác nhau'),
  // Luck
  AchDef('lucky_1', 'luck', Icons.celebration_rounded, AppColors.streak, 'lucky', 1, 20, 'Lucky Duck', 'Vịt May Mắn', 'Find a surprise reward', 'Tìm thấy một phần thưởng bất ngờ'),
  AchDef('lucky_5', 'luck', Icons.card_giftcard_rounded, AppColors.streak, 'lucky', 5, 60, 'Golden Goose', 'Ngỗng Vàng', 'Find 5 surprise rewards', 'Tìm thấy 5 phần thưởng bất ngờ'),
  // Collection
  AchDef('chests_5', 'collect', Icons.inventory_2_rounded, AppColors.streak, 'chests', 5, 40, 'Treasure Hunter', 'Thợ Săn Kho Báu', 'Open 5 chapter chests', 'Mở 5 rương chương'),
  AchDef('chests_10', 'collect', Icons.inventory_rounded, AppColors.streak, 'chests', 10, 80, 'Chest Collector', 'Nhà Sưu Tập Rương', 'Open 10 chapter chests', 'Mở 10 rương chương'),
  AchDef('wardrobe_10', 'collect', Icons.checkroom_rounded, AppColors.secondary, 'owned', 10, 50, 'Fashionista', 'Sành Điệu', 'Collect 10 duck items', 'Sưu tập 10 món đồ cho vịt'),
  AchDef('wardrobe_25', 'collect', Icons.style_rounded, _purple, 'owned', 25, 120, 'Wardrobe King', 'Vua Tủ Đồ', 'Collect 25 duck items', 'Sưu tập 25 món đồ cho vịt'),
];

AchDef? achOf(String id) {
  for (final a in kAch) {
    if (a.id == id) return a;
  }
  return null;
}

// ───────────────────────── dữ liệu / kết quả ─────────────────────────
/// Kết quả một phiên học, gửi cho MetaNotifier.onSessionDone.
class SessionResult {
  final String mode; // node | boss | practice | review | mistakes
  final int total, mistakes, acc, seconds, bestCombo, earnedXp, labsPassed, hour;
  final bool passed;
  final String bossId;
  final List<String> qids; // lần làm đầu của mỗi câu
  final List<bool> oks;
  const SessionResult({
    required this.mode,
    required this.total,
    required this.mistakes,
    required this.acc,
    required this.seconds,
    required this.bestCombo,
    required this.earnedXp,
    required this.labsPassed,
    required this.hour,
    required this.passed,
    required this.bossId,
    required this.qids,
    required this.oks,
  });
}

class SurpriseReward {
  final int xp;
  final List<String> items; // 'freeze' | 'xp2'
  final DuckItem? duck;
  final bool mega;
  const SurpriseReward(this.xp, this.items, this.duck, this.mega);
}

class MetaOutcome {
  final List<QuestDef> questsDone; // vừa đạt mục tiêu (chưa nhận thưởng)
  final List<String> badges; // id huy hiệu vừa mở
  final SurpriseReward? surprise;
  const MetaOutcome(this.questsDone, this.badges, this.surprise);
  bool get isEmpty => questsDone.isEmpty && badges.isEmpty && surprise == null;
}

class QuestClaim {
  final int xp, bonusXp;
  final String? bonusItem;
  final List<String> badges;
  const QuestClaim(this.xp, this.bonusXp, this.bonusItem, this.badges);
}

class MetaState {
  final int day;
  final Map<String, int> prog, cnt, ach; // tiến độ hôm nay, bộ đếm trọn đời, huy hiệu -> ngày mở
  final Set<int> claimed; // chỉ số nhiệm vụ hôm nay đã nhận
  final bool bonus;
  final List<int> qdays;
  final Set<String> lost; // boss đã thua
  final int luckyDay, luckyToday, luckySince;
  const MetaState({
    this.day = 0,
    this.prog = const {},
    this.cnt = const {},
    this.ach = const {},
    this.claimed = const {},
    this.bonus = false,
    this.qdays = const [],
    this.lost = const {},
    this.luckyDay = 0,
    this.luckyToday = 0,
    this.luckySince = 0,
  });

  MetaState copy({
    int? day,
    Map<String, int>? prog,
    Map<String, int>? cnt,
    Map<String, int>? ach,
    Set<int>? claimed,
    bool? bonus,
    List<int>? qdays,
    Set<String>? lost,
    int? luckyDay,
    int? luckyToday,
    int? luckySince,
  }) =>
      MetaState(
        day: day ?? this.day,
        prog: prog ?? this.prog,
        cnt: cnt ?? this.cnt,
        ach: ach ?? this.ach,
        claimed: claimed ?? this.claimed,
        bonus: bonus ?? this.bonus,
        qdays: qdays ?? this.qdays,
        lost: lost ?? this.lost,
        luckyDay: luckyDay ?? this.luckyDay,
        luckyToday: luckyToday ?? this.luckyToday,
        luckySince: luckySince ?? this.luckySince,
      );
}

/// Qua ngày mới thì tiến độ nhiệm vụ về 0 (hàm thuần, UI gọi trước khi hiển thị).
MetaState rolled(MetaState s) {
  final t = dayNum();
  if (s.day == t) return s;
  return s.copy(day: t, prog: const {}, claimed: const {}, bonus: false);
}

int questsDoneCount(MetaState s) {
  final r = rolled(s);
  return questsFor(r.day).where((q) => (r.prog[q.kind] ?? 0) >= q.target).length;
}

int questsClaimable(MetaState s) {
  final r = rolled(s);
  final defs = questsFor(r.day);
  var n = 0;
  for (var i = 0; i < defs.length; i++) {
    if ((r.prog[defs[i].kind] ?? 0) >= defs[i].target && !r.claimed.contains(i)) n++;
  }
  return n;
}

Map<String, int> _intMap(dynamic v) {
  final out = <String, int>{};
  if (v is Map) {
    v.forEach((k, x) {
      if (x is num) out['$k'] = x.toInt();
    });
  }
  return out;
}

// ───────────────────────── notifier ─────────────────────────
class MetaNotifier extends Notifier<MetaState> {
  Box get _box => Hive.box('stats');
  final Random _rnd = Random();

  @override
  MetaState build() {
    var s = const MetaState();
    try {
      final raw = _box.get('x_meta');
      if (raw is String && raw.isNotEmpty) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        s = MetaState(
          day: (j['d'] as num?)?.toInt() ?? 0,
          prog: _intMap(j['p']),
          cnt: _intMap(j['cnt']),
          ach: _intMap(j['ach']),
          claimed: ((j['c'] as List?) ?? const []).map((e) => (e as num).toInt()).toSet(),
          bonus: j['b'] == 1,
          qdays: ((j['qd'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
          lost: ((j['lost'] as List?) ?? const []).map((e) => '$e').toSet(),
          luckyDay: (j['ld'] as num?)?.toInt() ?? 0,
          luckyToday: (j['ln'] as num?)?.toInt() ?? 0,
          luckySince: (j['ls'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (_) {}
    return rolled(s);
  }

  MetaState get _cur {
    final r = rolled(state);
    if (!identical(r, state)) state = r;
    return r;
  }

  void _save() {
    final s = state;
    _box.put(
        'x_meta',
        jsonEncode({
          'd': s.day,
          'p': s.prog,
          'cnt': s.cnt,
          'ach': s.ach,
          'c': s.claimed.toList(),
          'b': s.bonus ? 1 : 0,
          'qd': s.qdays,
          'lost': s.lost.toList(),
          'ld': s.luckyDay,
          'ln': s.luckyToday,
          'ls': s.luckySince,
        }));
  }

  /// Mở màn Quests sau nửa đêm: đổi sang bộ nhiệm vụ của ngày mới.
  void refresh() {
    final before = state;
    final r = _cur;
    if (!identical(before, r)) _save();
  }

  void _grant(int xp) {
    if (xp <= 0) return;
    ref.read(statsProvider.notifier).addXp(xp);
    ref.read(extrasProvider.notifier).addXp(xp);
    ref.read(historyProvider.notifier).addXp(xp);
  }

  void _add(Map<String, int> m, String k, [int by = 1]) => m[k] = (m[k] ?? 0) + by;

  /// Gọi MỘT lần khi phiên học kết thúc (sau khi đã cộng XP / streak).
  MetaOutcome onSessionDone(SessionResult r) {
    var s = _cur;
    final cnt = Map<String, int>.from(s.cnt);
    final prog = Map<String, int>.from(s.prog);
    final before = Map<String, int>.from(prog);
    final lost = Set<String>.from(s.lost);

    final okN = r.oks.where((e) => e).length;
    _add(cnt, 'lessons');
    _add(prog, 'lessons');
    _add(cnt, 'answers', r.qids.length);
    _add(prog, 'answers', r.qids.length);
    _add(cnt, 'correct', okN);
    _add(prog, 'correct', okN);
    _add(prog, 'xp', r.earnedXp);

    if (r.mistakes == 0 && r.total >= 3) {
      _add(cnt, 'perfect');
      _add(prog, 'perfect');
    }
    if (r.seconds <= 90 && r.total >= 5 && r.acc >= 80) {
      _add(cnt, 'fast');
      _add(prog, 'fast');
    }
    if (r.mode == 'review' || r.mode == 'mistakes') {
      _add(cnt, 'fixed', okN);
      _add(prog, 'fixed', okN);
      _add(prog, 'review');
    }
    if (r.labsPassed > 0) {
      _add(cnt, 'labs', r.labsPassed);
      _add(prog, 'lab', r.labsPassed);
    }
    if (r.hour >= 23 || r.hour < 4) _add(cnt, 'night');
    if (r.hour >= 4 && r.hour < 7) _add(cnt, 'early');

    if (r.mode == 'boss') {
      if (r.passed) {
        _add(cnt, 'bossWins');
        if (r.acc >= 100) _add(cnt, 'bossFlawless');
        if (lost.remove(r.bossId)) _add(cnt, 'revenge');
      } else {
        lost.add(r.bossId);
      }
    }

    // sai nhiều lần cùng một câu / làm đúng câu từng sai nhiều lần
    final recs = ref.read(studyProvider).recs;
    var wm = cnt['wrongMax'] ?? 0;
    for (var i = 0; i < r.qids.length; i++) {
      final rec = recs[r.qids[i]];
      if (rec == null) continue;
      final w = rec.a - rec.c;
      wm = max(wm, w);
      if (i < r.oks.length && r.oks[i] && w >= 3) _add(cnt, 'phoenix');
    }
    cnt['wrongMax'] = wm;

    cnt['combo'] = max(cnt['combo'] ?? 0, r.bestCombo);
    cnt['dayAnswers'] = max(cnt['dayAnswers'] ?? 0, prog['answers'] ?? 0);
    cnt['streak'] = max(cnt['streak'] ?? 0, ref.read(statsProvider).streak);
    cnt['chests'] = max(cnt['chests'] ?? 0, ref.read(bagProvider).chests.length);
    cnt['owned'] = max(cnt['owned'] ?? 0, ref.read(duckProvider).owned.where((e) => e != 'white').length);

    // phần thưởng bất ngờ
    final lk = [s.luckyDay, s.luckyToday, s.luckySince];
    final today = dayNum();
    if (lk[0] != today) {
      lk[0] = today;
      lk[1] = 0;
    }
    lk[2] += 1;
    SurpriseReward? sur;
    final eligible = r.total >= 3 && !(r.mode == 'boss' && !r.passed);
    if (eligible) sur = _rollSurprise(lk);
    if (sur != null) _add(cnt, 'lucky');

    state = s.copy(prog: prog, cnt: cnt, lost: lost, luckyDay: lk[0], luckyToday: lk[1], luckySince: lk[2]);
    _save();

    final badges = _evaluate();
    final done = <QuestDef>[
      for (final q in questsFor(state.day))
        if ((before[q.kind] ?? 0) < q.target && (prog[q.kind] ?? 0) >= q.target) q
    ];
    return MetaOutcome(done, badges, sur);
  }

  SurpriseReward? _rollSurprise(List<int> lk) {
    if (lk[1] >= kLuckyMaxPerDay) return null;
    final chance = min(0.40, 0.08 + 0.025 * lk[2]);
    final force = lk[2] >= 12;
    if (!force && _rnd.nextDouble() >= chance) return null;
    lk[1] += 1;
    lk[2] = 0;

    final bag = ref.read(bagProvider.notifier);
    final roll = _rnd.nextInt(100);
    var xp = 0;
    final items = <String>[];
    DuckItem? duck;
    var mega = false;

    DuckItem? award() => ref
        .read(duckProvider.notifier)
        .awardForChapter('lucky:${DateTime.now().millisecondsSinceEpoch}:${_rnd.nextInt(100000)}');

    if (roll < 45) {
      xp = 20 + _rnd.nextInt(26);
    } else if (roll < 65) {
      if (ref.read(bagProvider).freeze < kMaxFreeze) {
        items.add(bag.give('freeze'));
      } else {
        xp = 30;
      }
    } else if (roll < 85) {
      items.add(bag.give('xp2'));
    } else if (roll < 97) {
      duck = award();
      if (duck == null) xp = 40;
    } else {
      mega = true;
      xp = 100;
      items.add(bag.give('xp2'));
      duck = award();
    }
    _grant(xp);
    return SurpriseReward(xp, items, duck, mega);
  }

  /// Mở huy hiệu mới nếu bộ đếm đã đủ. Trả về id các huy hiệu vừa mở (đã cộng XP thưởng).
  List<String> _evaluate() {
    final s = state;
    final ach = Map<String, int>.from(s.ach);
    final out = <String>[];
    var xp = 0;
    for (final a in kAch) {
      if (ach.containsKey(a.id)) continue;
      if ((s.cnt[a.counter] ?? 0) >= a.goal) {
        ach[a.id] = dayNum();
        out.add(a.id);
        xp += a.xp;
      }
    }
    if (out.isNotEmpty) {
      state = s.copy(ach: ach);
      _save();
      _grant(xp);
    }
    return out;
  }

  /// Nhận thưởng nhiệm vụ thứ i của hôm nay. Null nếu chưa đạt hoặc đã nhận.
  QuestClaim? claim(int i) {
    final s = _cur;
    final defs = questsFor(s.day);
    if (i < 0 || i >= defs.length) return null;
    final q = defs[i];
    if (s.claimed.contains(i) || (s.prog[q.kind] ?? 0) < q.target) return null;

    _grant(q.xp);
    final claimed = <int>{...s.claimed, i};
    final cnt = Map<String, int>.from(s.cnt);
    _add(cnt, 'claims');
    var bonus = s.bonus;
    final qd = List<int>.of(s.qdays);
    var bonusXp = 0;
    String? bonusItem;
    if (claimed.length >= defs.length && !bonus) {
      bonus = true;
      bonusXp = kQuestBonusXp;
      _grant(bonusXp);
      bonusItem = ref.read(bagProvider.notifier).give(_rnd.nextInt(100) < 50 ? 'freeze' : 'xp2');
      qd.add(s.day);
      cnt['qdays'] = qd.length;
    }
    state = s.copy(claimed: claimed, bonus: bonus, qdays: qd, cnt: cnt);
    _save();
    final badges = _evaluate();
    return QuestClaim(q.xp, bonusXp, bonusItem, badges);
  }

  void reset() {
    _box.delete('x_meta');
    state = rolled(const MetaState());
  }
}

final metaProvider = NotifierProvider<MetaNotifier, MetaState>(MetaNotifier.new);
