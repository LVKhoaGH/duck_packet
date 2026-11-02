import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bag.dart';
import 'backup_service.dart';
import 'bag_screen.dart';
import 'extras.dart';
import 'history.dart';
import 'settings_screen.dart';
import 'stats_chart.dart';
import 'titles.dart';
import 'models.dart';
import 'providers.dart';
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
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45)),
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
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38)),
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
    final title = titleFor(stats.xp);

    return ListView(padding: const EdgeInsets.all(20), children: [
      Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          tooltip: tr('Settings'),
          icon: const Icon(Icons.settings_rounded, size: 28, color: Color(0xFFAFAFAF)),
          onPressed: () => Navigator.push(context, slideUpRoute(const SettingsScreen())),
        ),
      ),
      Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.tint,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 4),
          ),
          child: ClipOval(
            child: Image.asset('assets/mascot/duck_happy.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 60)),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const Center(child: Text('Duck Learner', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink))),
      const SizedBox(height: 4),
      Center(child: Text(title.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: title.color))),
      Center(child: Text(c?.title ?? 'No course imported', style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w700))),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: duoCard(border: AppColors.primary, fill: AppColors.tint, shadow: AppColors.primaryShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Level ${stats.xp ~/ 100 + 1}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryShadow)),
            const Spacer(),
            Text('${stats.xp % 100} / 100 XP', style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          ProgressBar3D((stats.xp % 100) / 100, track: Colors.white),
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
            const Text('Daily goal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const Spacer(),
            Text('${extras.todayXp} / ${extras.goal} XP',
                style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w700)),
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
                              color: extras.goal == g ? AppColors.primaryShadow : Colors.black45)),
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
      ]),
      const SizedBox(height: 14),
      const ProgressChartCard(),
      const SizedBox(height: 24),
      const Text('Statistics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
      const SizedBox(height: 10),
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
      const SizedBox(height: 24),
      const Text('This week', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.all(16), decoration: duoCard(), child: WeekRow(stats.days)),
      const SizedBox(height: 24),
      const Text('Data', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
      const SizedBox(height: 10),
      Button3D(label: 'Course library', onPressed: onImport),
      const SizedBox(height: 10),
      Button3D(label: 'Backup progress', color: AppColors.success, shadow: AppColors.successShadow, onPressed: () => _backup(context, ref)),
      const SizedBox(height: 10),
      Button3D(label: 'Restore backup', color: AppColors.secondary, shadow: AppColors.primaryShadow, onPressed: () => _restore(context, ref)),
      const SizedBox(height: 18),
      GestureDetector(
        onTap: () async {
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
          }
        },
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: duoCard(border: AppColors.error, shadow: AppColors.errorShadow),
          child: const Text('RESET PROGRESS', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        ),
      ),
      const SizedBox(height: 40),
    ]);
  }
}
