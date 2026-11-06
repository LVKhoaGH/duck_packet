import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'duck.dart';
import 'game_session_screen.dart';
import 'glossary_screen.dart';
import 'models.dart';
import 'providers.dart';
import 'sfx.dart';
import 'study.dart';
import 'theme.dart';
import 'widgets.dart';

/// Practice hub: domain mastery, mistakes, spaced review, quick mix, glossary.
class PracticeTab extends ConsumerWidget {
  final Course? course;
  const PracticeTab({super.key, required this.course});

  void _start(BuildContext context, String title, List<Question> qs, SessionMode mode) {
    final node = CourseNode(id: 'practice', title: title, icon: 'router.svg', questions: qs);
    Navigator.push(context, slideUpRoute(GameSessionScreen(node: node, mode: mode)));
  }

  Color _barColor(double v) => v >= 0.7 ? AppColors.success : (v >= 0.4 ? AppColors.streak : AppColors.error);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = course;
    if (c == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Import a course to unlock practice.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 16)),
        ),
      );
    }
    final study = ref.watch(studyProvider);
    final done = ref.watch(statsProvider).completed;
    final idx = indexCourse(c);
    final today = dayNum();

    final dueQs = <Question>[];
    final wrongQs = <Question>[];
    study.recs.forEach((id, r) {
      final qr = idx[id];
      if (qr == null) return;
      if (r.wrong) wrongQs.add(qr.q);
      if (r.enrolled && r.due <= today) dueQs.add(qr.q);
    });
    final mixPool = <Question>[for (final n in c.allNodes) if (done.contains(n.id)) ...n.questions.where((q) => q.type != 'lab')];
    final labPool = <Question>[for (final n in c.allNodes) for (final q in n.questions) if (q.type == 'lab') q];

    final domains = domainStats(c);
    DomainStat? weakest;
    for (final d in domains) {
      if (d.attempted(study.recs) == 0) continue;
      if (weakest == null || d.mastery(study.recs) < weakest.mastery(study.recs)) weakest = d;
    }

    Widget tile(IconData icon, Color color, String title, String sub, int? count, VoidCallback? onTap) {
      final on = onTap != null;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: PressScale(
          scale: 0.98,
          onTap: on
              ? () {
                  Sfx.play('tap');
                  onTap!();
                }
              : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: on ? duoCard(border: color) : duoCard(border: AppColors.line, fill: const Color(0xFFF7F7F7), shadow: AppColors.line),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: on ? color : AppColors.locked, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: on ? AppColors.ink : AppColors.lockedShadow)),
                  Text(sub, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black38)),
                ]),
              ),
              if (count != null && count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
                  child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
        ),
      );
    }

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      Row(children: [
        const DuckView(size: 58),
        const SizedBox(width: 12),
        const Expanded(child: Text('Practice', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.ink))),
      ]),
      const SizedBox(height: 14),

      tile(
        Icons.event_repeat_rounded,
        AppColors.primary,
        'Review today',
        dueQs.isEmpty ? 'Nothing due. Come back tomorrow' : 'Spaced repetition: 1 · 3 · 7 days',
        dueQs.length,
        dueQs.isEmpty ? null : () => _start(context, 'Review today', (dueQs.toList()..shuffle()).take(10).toList(), SessionMode.review),
      ),
      tile(
        Icons.error_outline_rounded,
        AppColors.error,
        'Mistakes',
        wrongQs.isEmpty ? 'No mistakes to fix' : 'Questions you got wrong',
        wrongQs.length,
        wrongQs.isEmpty ? null : () => _start(context, 'Mistakes', (wrongQs.toList()..shuffle()).take(10).toList(), SessionMode.mistakes),
      ),
      tile(
        Icons.shuffle_rounded,
        AppColors.success,
        'Quick mix',
        mixPool.length >= 3 ? '10 random questions from beaten monsters' : 'Beat a monster to unlock',
        null,
        mixPool.length < 3 ? null : () => _start(context, 'Quick mix', (mixPool.toList()..shuffle()).take(10).toList(), SessionMode.practice),
      ),
      tile(
        Icons.menu_book_rounded,
        AppColors.secondary,
        'Glossary',
        c.glossary.isEmpty ? 'No terms in this course yet' : 'Terms and commands, searchable',
        c.glossary.length,
        () => Navigator.push(context, slideUpRoute(GlossaryScreen(items: c.glossary))),
      ),

      tile(
        Icons.terminal_rounded,
        AppColors.terminalBg,
        'Labs',
        labPool.isEmpty ? 'No labs in this course yet' : 'Hands-on CLI scenarios',
        labPool.length,
        labPool.isEmpty
            ? null
            : () => _start(context, 'Labs', (labPool.toList()..shuffle()).take(3).toList(), SessionMode.practice),
      ),
      const SizedBox(height: 14),
      const Text('Domain mastery', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
      const SizedBox(height: 4),
      const Text('% of questions whose latest first attempt was correct',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: duoCard(border: AppColors.line),
        child: Column(children: [
          for (final d in domains)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(d.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                  ),
                  if (identical(d, weakest))
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.error.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                      child: const Text('WEAKEST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.error, letterSpacing: 0.6)),
                    ),
                  Text('${(d.mastery(study.recs) * 100).round()}%',
                      style: TextStyle(fontWeight: FontWeight.w700, color: _barColor(d.mastery(study.recs)))),
                ]),
                const SizedBox(height: 6),
                ProgressBar3D(d.mastery(study.recs), track: AppColors.line, fill: _barColor(d.mastery(study.recs))),
                const SizedBox(height: 2),
                Text('${d.attempted(study.recs)} / ${d.qs.length} attempted',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black38)),
              ]),
            ),
          if (domains.isEmpty) const Text('No questions yet.', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700)),
          Button3D(
            label: weakest == null ? 'Play a lesson first' : 'Train weakest',
            onPressed: weakest == null
                ? null
                : () {
                    final w = weakest!;
                    final unmastered = w.qs.where((q) => study.recs[qidOf(q)]?.lastOk != true).toList()..shuffle();
                    final mastered = w.qs.where((q) => study.recs[qidOf(q)]?.lastOk == true).toList()..shuffle();
                    _start(context, w.label, [...unmastered, ...mastered].take(10).toList(), SessionMode.practice);
                  },
          ),
        ]),
      ),
    ]);
  }
}
