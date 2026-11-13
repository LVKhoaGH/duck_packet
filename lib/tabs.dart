import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bag.dart';
import 'duck.dart';
import 'backup_service.dart';
import 'bag_screen.dart';
import 'extras.dart';
import 'history.dart';
import 'settings_screen.dart';
import 'stats_chart.dart';
import 'titles.dart';
import 'models.dart';
import 'providers.dart';
import 'quests.dart';
import 'quests_screen.dart';
import 'sfx.dart';
import 'study.dart';
import 'theme.dart';
import 'widgets.dart';

// ───────────────────────── Profile ─────────────────────────
class ProfileTab extends ConsumerWidget {
  final Course? course;
  final VoidCallback onImport;
  const ProfileTab({super.key, required this.course, required this.onImport});

  Widget _card(Widget icon, String value, String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: duoCard(),
          child: Column(children: [
            icon,
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.sub)),
          ]),
        ),
      );

  Widget _tile(IconData icon, Color color, String title, String sub, VoidCallback onTap) => Expanded(
        child: PressScale(
          scale: 0.97,
          onTap: () {
            Sfx.play('tap');
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: duoCard(border: color),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 6),
              Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.faint)),
            ]),
          ),
        ),
      );

  void _snack(BuildContext c, String t) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    try {
      final msg = await ref.read(backupServiceProvider).export();
      if (msg != null && context.mounted) _snack(context, msg);
    } catch (e) {
      if (context.mounted) _snack(context, 'Backup failed: $e');
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text('Current progress will be replaced by the backup file.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('CHOOSE FILE')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final msg = await ref.read(backupServiceProvider).restore();
      if (msg != null && context.mounted) _snack(context, msg);
    } catch (e) {
      if (context.mounted) _snack(context, 'Restore failed: $e');
    }
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text('XP, streak, cleared stages, mistakes, history and bag items will be cleared.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('RESET', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) {
      Sfx.play('tap');
      ref.read(statsProvider.notifier).reset();
      ref.read(extrasProvider.notifier).reset();
      ref.read(studyProvider.notifier).reset();
      ref.read(historyProvider.notifier).reset();
      ref.read(bagProvider.notifier).reset();
      ref.read(metaProvider.notifier).reset();
      ref.read(duckProvider.notifier).reset();
      ref.read(duckMuscleProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final extras = ref.watch(extrasProvider);
    final c = course;
    final stages = c == null ? <String>[] : stageIds(c);
    final cleared = stages.where(stats.completed.contains).length;
    final bosses = c == null ? 0 : c.chapters.where((ch) => ch.nodes.isNotEmpty && stats.completed.contains(bossId(ch))).length;
    final totalBosses = c == null ? 0 : c.chapters.where((ch) => ch.nodes.isNotEmpty).length;
    final pct = stages.isEmpty ? 0 : (cleared * 100 / stages.length).round();

    final bag = ref.watch(bagProvider);
    final meta = ref.watch(metaProvider);
    final claimable = questsClaimable(meta);
    final badgesGot = kAch.where((a) => meta.ach.containsKey(a.id)).length;
    final title = titleFor(stats.xp);
    final duck = ref.watch(duckProvider);
    final duckGot = duck.owned.where((e) => e != 'white').length;
    void openDuck() => Navigator.push(context, slideUpRoute(const DuckScreen()));

    return ListView(padding: const EdgeInsets.all(20), children: [
      Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          tooltip: tr('Settings'),
          icon: Icon(Icons.settings_rounded, size: 28, color: AppColors.icon),
          onPressed: () => Navigator.push(context, slideUpRoute(const SettingsScreen())),
        ),
      ),
      Center(
        child: Container(
          width: 120,
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.tint,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 4),
          ),
          child: DuckView(size: 84, onTap: openDuck),
        ),
      ),
      const SizedBox(height: 12),
      Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: openDuck,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Text(duck.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink)),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.edit_rounded, size: 18, color: AppColors.secondary),
          ]),
        ),
      ),
      const SizedBox(height: 4),
      Center(child: Text(title.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: title.color))),
      Center(child: Text(c?.title ?? 'No course imported', style: TextStyle(color: AppColors.sub, fontWeight: FontWeight.w700))),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: duoCard(border: AppColors.primary, fill: AppColors.tint, shadow: AppColors.primaryShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Level ${stats.xp ~/ 100 + 1}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryShadow)),
            const Spacer(),
            Text('${stats.xp % 100} / 100 XP', style: TextStyle(color: AppColors.sub, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          ProgressBar3D((stats.xp % 100) / 100, track: AppColors.surface),
        ]),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: duoCard(border: extras.goalDone ? AppColors.success : AppColors.line),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(extras.goalDone ? Icons.check_circle_rounded : Icons.flag_rounded,
                color: extras.goalDone ? AppColors.success : AppColors.streak),
            const SizedBox(width: 8),
            Text('Daily goal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const Spacer(),
            Text('${extras.todayXp} / ${extras.goal} XP',
                style: TextStyle(color: AppColors.sub, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          ProgressBar3D((extras.todayXp / extras.goal).clamp(0.0, 1.0).toDouble(), track: AppColors.line),
          const SizedBox(height: 12),
          Row(children: [
            for (final g in kGoalOptions)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: g == kGoalOptions.last ? 0 : 8),
                  child: PressScale(
                    onTap: () {
                      Sfx.play('tap');
                      ref.read(extrasProvider.notifier).setGoal(g);
                    },
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: extras.goal == g
                          ? duoCard(border: AppColors.primary, fill: AppColors.tint, shadow: AppColors.primaryShadow, radius: 12)
                          : duoCard(radius: 12),
                      child: Text('$g XP',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: extras.goal == g ? AppColors.primaryShadow : AppColors.sub)),
                    ),
                  ),
                ),
              ),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        _tile(Icons.backpack_rounded, AppColors.streak, 'Bag', '${bag.freeze} freeze · ${bag.xp2} x2',
            () => Navigator.push(context, slideUpRoute(const BagScreen()))),
        const SizedBox(width: 10),
        _tile(title.icon, title.color, 'Titles', title.name,
            () => Navigator.push(context, slideUpRoute(const TitlesScreen()))),
        const SizedBox(width: 10),
        _tile(Icons.checkroom_rounded, AppColors.secondary, 'Wardrobe', '$duckGot unlocked', openDuck),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _tile(Icons.task_alt_rounded, AppColors.success, 'Quests',
            claimable > 0 ? 'Claim reward!' : '${questsDoneCount(meta)}/3 done',
            () => Navigator.push(context, slideUpRoute(const QuestsScreen()))),
        const SizedBox(width: 10),
        _tile(Icons.military_tech_rounded, AppColors.error, 'Badges', '$badgesGot/${kAch.length} unlocked',
            () => Navigator.push(context, slideUpRoute(const BadgesScreen()))),
      ]),
      const SizedBox(height: 14),
      const _Fold(title: 'Progress chart', child: ProgressChartCard()),
      const SizedBox(height: 10),
      _Fold(
        title: 'Statistics',
        open: true,
        child: Column(children: [
          Row(children: [
            _card(const SvgIcon('ic_fire', size: 30), '${stats.streak}', 'Day streak', AppColors.streak),
            const SizedBox(width: 10),
            _card(const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 30), '${stats.xp}', 'Total XP', AppColors.primary),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _card(const Icon(Icons.flag_rounded, color: AppColors.success, size: 30), '$pct%', 'Course cleared', AppColors.success),
            const SizedBox(width: 10),
            _card(const Icon(Icons.whatshot_rounded, color: AppColors.error, size: 30), '$bosses/$totalBosses', 'Bosses', AppColors.error),
          ]),
        ]),
      ),
      const SizedBox(height: 10),
      _Fold(
        title: 'This week',
        child: Container(padding: const EdgeInsets.all(16), decoration: duoCard(), child: WeekRow(stats.days)),
      ),
      const SizedBox(height: 10),
      _Fold(
        title: 'Data',
        child: Column(children: [
          Button3D(label: 'Course library', onPressed: onImport),
          const SizedBox(height: 10),
          Button3D(label: 'Backup progress', color: AppColors.success, shadow: AppColors.successShadow, onPressed: () => _backup(context, ref)),
          const SizedBox(height: 10),
          Button3D(label: 'Restore backup', color: AppColors.secondary, shadow: AppColors.primaryShadow, onPressed: () => _restore(context, ref)),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () => _reset(context, ref),
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: duoCard(border: AppColors.error, shadow: AppColors.errorShadow),
              child: const Text('RESET PROGRESS', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 40),
    ]);
  }
}

/// Collapsible section used on the Profile tab.
class _Fold extends StatefulWidget {
  final String title;
  final bool open;
  final Widget child;
  const _Fold({required this.title, required this.child, this.open = false});
  @override
  State<_Fold> createState() => _FoldState();
}

class _FoldState extends State<_Fold> {
  late bool _open = widget.open;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PressScale(
          scale: 0.99,
          onTap: () {
            Sfx.play('tap');
            setState(() => _open = !_open);
          },
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: duoCard(),
            child: Row(children: [
              Expanded(
                child: Text(widget.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ),
              Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.locked),
            ]),
          ),
        ),
        if (_open) Padding(padding: const EdgeInsets.only(top: 10), child: widget.child),
      ]);
}
