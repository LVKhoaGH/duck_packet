// quests_screen.dart  (FILE MỚI)  Màn Nhiệm vụ, màn Huy hiệu, và các popup thưởng.
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bag_screen.dart' show itemInfo;
import 'duck.dart' show showDuckUnlock;
import 'duck_mood.dart' show DuckFace, DuckFaceView;
import 'i18n.dart';
import 'quests.dart';
import 'sfx.dart';
import 'theme.dart';
import 'widgets.dart';

// ───────────────────────── popup thưởng ─────────────────────────
Widget _rowCard(IconData icon, Color color, String title, String sub, {String? trailing}) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: duoCard(border: color, radius: 14),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
            if (sub.isNotEmpty)
              Text(sub, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45)),
          ]),
        ),
        if (trailing != null)
          Text(trailing, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ]),
    );

Future<void> _dialog(BuildContext context, DuckFace face, String title, List<Widget> rows, {String button = 'Awesome!'}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DuckFaceView(face: face, size: 110),
            const SizedBox(height: 4),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 12),
            Flexible(child: SingleChildScrollView(child: Column(children: rows))),
            const SizedBox(height: 10),
            Button3D(label: button, onPressed: () => Navigator.pop(ctx)),
          ]),
        ),
      ),
    ),
  );
}

List<Widget> _badgeRows(List<String> ids) => [
      for (var i = 0; i < ids.length; i++)
        if (achOf(ids[i]) != null)
          Pop(
            delay: 120 * i,
            child: _rowCard(achOf(ids[i])!.icon, achOf(ids[i])!.color, achOf(ids[i])!.name, achOf(ids[i])!.desc,
                trailing: '+${achOf(ids[i])!.xp} XP'),
          ),
    ];

/// Sau một phiên học: nhiệm vụ vừa đạt, huy hiệu mới, rồi phần thưởng bất ngờ.
Future<void> showRewardDialogs(BuildContext context, WidgetRef ref, MetaOutcome o) async {
  if (o.questsDone.isNotEmpty || o.badges.isNotEmpty) {
    Sfx.play('success');
    final rows = <Widget>[
      for (final q in o.questsDone) _rowCard(q.icon, AppColors.success, 'Quest complete!', q.text, trailing: '+${q.xp} XP'),
      ..._badgeRows(o.badges),
    ];
    if (o.questsDone.isNotEmpty) {
      rows.add(const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text('Claim quest rewards in Profile → Quests.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45)),
      ));
    }
    await _dialog(context, o.badges.isNotEmpty ? DuckFace.cheer : DuckFace.cool,
        o.badges.isNotEmpty ? 'New badge!' : 'Nice work!', rows);
  }
  final sr = o.surprise;
  if (sr != null && context.mounted) {
    Sfx.play('streak');
    final rows = <Widget>[
      if (sr.xp > 0) Pop(delay: 100, child: _rowCard(Icons.bolt_rounded, AppColors.primary, '+${sr.xp} XP', '', trailing: null)),
      for (var i = 0; i < sr.items.length; i++)
        Pop(
          delay: 250 + 150 * i,
          child: _rowCard(itemInfo(sr.items[i]).icon, itemInfo(sr.items[i]).color, '${itemInfo(sr.items[i]).name} x1', ''),
        ),
      if (sr.duck != null) Pop(delay: 600, child: _rowCard(Icons.checkroom_rounded, AppColors.secondary, 'A new duck item!', '')),
    ];
    await _dialog(context, sr.mega ? DuckFace.love : DuckFace.surprised, sr.mega ? 'JACKPOT!' : 'Surprise reward!', rows);
    if (sr.duck != null && context.mounted) await showDuckUnlock(context, ref, sr.duck!);
  }
}

Future<void> showClaimDialog(BuildContext context, QuestClaim c) {
  final rows = <Widget>[
    Pop(child: _rowCard(Icons.bolt_rounded, AppColors.primary, '+${c.xp} XP', '')),
    if (c.bonusXp > 0)
      Pop(delay: 150, child: _rowCard(Icons.celebration_rounded, AppColors.streak, 'All quests done!', 'Daily bonus', trailing: '+${c.bonusXp} XP')),
    if (c.bonusItem != null)
      Pop(
        delay: 300,
        child: _rowCard(itemInfo(c.bonusItem!).icon, itemInfo(c.bonusItem!).color, '${itemInfo(c.bonusItem!).name} x1', 'Daily bonus'),
      ),
    ..._badgeRows(c.badges),
  ];
  return _dialog(context, c.bonusXp > 0 || c.badges.isNotEmpty ? DuckFace.cheer : DuckFace.happy,
      c.bonusXp > 0 ? 'Daily bonus!' : 'Reward claimed!', rows);
}

// ───────────────────────── màn Nhiệm vụ ─────────────────────────
class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});
  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(metaProvider.notifier).refresh();
    });
  }

  Future<void> _claim(int i) async {
    final c = ref.read(metaProvider.notifier).claim(i);
    if (c == null) return;
    Sfx.play('success');
    await showClaimDialog(context, c);
  }

  @override
  Widget build(BuildContext context) {
    final s = rolled(ref.watch(metaProvider));
    final defs = questsFor(s.day);
    final allClaimed = s.claimed.length >= defs.length;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 4),
            child: Row(children: [
              IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 28, color: Color(0xFFAFAFAF)),
                  onPressed: () => Navigator.pop(context)),
              const Expanded(child: Text('Daily quests', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink))),
              Text('${questsDoneCount(s)}/${defs.length}', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black45)),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              Row(children: [
                DuckFaceView(face: allClaimed ? DuckFace.cheer : DuckFace.determined, size: 84),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('New quests every day. Finish all 3 for a bonus!',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black54)),
                ),
              ]),
              const SizedBox(height: 12),
              for (var i = 0; i < defs.length; i++) _questCard(s, defs[i], i),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: s.bonus
                    ? duoCard(border: AppColors.success, fill: const Color(0xFFE6F8F0), shadow: AppColors.successShadow)
                    : duoCard(border: AppColors.streak, fill: const Color(0xFFFFF3D6), shadow: AppColors.streakShadow),
                child: Row(children: [
                  Icon(s.bonus ? Icons.check_circle_rounded : Icons.card_giftcard_rounded,
                      color: s.bonus ? AppColors.success : AppColors.streakShadow, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.bonus ? 'Daily bonus claimed' : 'Daily bonus: +$kQuestBonusXp XP and a free item when all 3 are claimed',
                      style: TextStyle(fontWeight: FontWeight.w700, color: s.bonus ? AppColors.successShadow : AppColors.streakShadow),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                _stat('${s.qdays.length}', 'Days completed', AppColors.success),
                const SizedBox(width: 10),
                _stat('${s.cnt['claims'] ?? 0}', 'Rewards claimed', AppColors.primary),
              ]),
              const SizedBox(height: 18),
              Button3D(
                label: 'Badges',
                color: AppColors.secondary,
                shadow: AppColors.primaryShadow,
                onPressed: () => Navigator.push(context, slideUpRoute(const BadgesScreen())),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _stat(String v, String label, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: duoCard(),
          child: Column(children: [
            Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c)),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45)),
          ]),
        ),
      );

  Widget _questCard(MetaState s, QuestDef q, int i) {
    final cur = (s.prog[q.kind] ?? 0).clamp(0, q.target).toInt();
    final done = cur >= q.target;
    final claimed = s.claimed.contains(i);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: claimed
          ? duoCard(border: AppColors.line, fill: const Color(0xFFF7F7F7), shadow: AppColors.line)
          : duoCard(border: done ? AppColors.success : AppColors.line),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: claimed ? AppColors.locked : (done ? AppColors.success : AppColors.primary), borderRadius: BorderRadius.circular(14)),
          child: Icon(claimed ? Icons.check_rounded : q.icon, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(q.text,
                style: TextStyle(fontSize: 15, height: 1.25, fontWeight: FontWeight.w700, color: claimed ? AppColors.lockedShadow : AppColors.ink)),
            const SizedBox(height: 6),
            ProgressBar3D(cur / q.target, track: AppColors.line, fill: done ? AppColors.success : AppColors.primary),
            const SizedBox(height: 2),
            Text('$cur / ${q.target}   ·   +${q.xp} XP',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black38)),
          ]),
        ),
        if (done && !claimed) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: Button3D(
              label: 'Claim',
              color: AppColors.streak,
              shadow: AppColors.streakShadow,
              onPressed: () => _claim(i),
            ),
          ),
        ],
      ]),
    );
  }
}

// ───────────────────────── màn Huy hiệu ─────────────────────────
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = rolled(ref.watch(metaProvider));
    final got = kAch.where((a) => s.ach.containsKey(a.id)).length;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 4),
            child: Row(children: [
              IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 28, color: Color(0xFFAFAFAF)),
                  onPressed: () => Navigator.pop(context)),
              const Expanded(child: Text('Badges', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink))),
              Text('$got / ${kAch.length}', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black45)),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
              ProgressBar3D(got / kAch.length, track: AppColors.line, fill: AppColors.streak),
              const SizedBox(height: 8),
              for (final g in kAchGroups) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 8),
                  child: Text(g.value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
                ),
                for (final a in kAch.where((a) => a.group == g.key)) _badge(a, s),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _badge(AchDef a, MetaState s) {
    final on = s.ach.containsKey(a.id);
    final cur = (s.cnt[a.counter] ?? 0).clamp(0, a.goal).toInt();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: on ? duoCard(border: a.color) : duoCard(border: AppColors.line, fill: const Color(0xFFF7F7F7), shadow: AppColors.line),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: on ? a.color : AppColors.locked, borderRadius: BorderRadius.circular(14)),
          child: Icon(on ? a.icon : Icons.lock_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.name,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: on ? AppColors.ink : AppColors.lockedShadow)),
            Text(a.desc, style: const TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w700, color: Colors.black45)),
            if (!on && a.goal > 1) ...[
              const SizedBox(height: 6),
              ProgressBar3D(cur / a.goal, track: AppColors.line, fill: a.color),
              Text('$cur / ${a.goal}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black38)),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        if (on)
          const Icon(Icons.check_circle_rounded, color: AppColors.success)
        else
          Text('+${a.xp} XP', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38)),
      ]),
    );
  }
}
