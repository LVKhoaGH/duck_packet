import 'dart:convert';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'duck.dart';
import 'i18n.dart';
import 'library.dart';
import 'models.dart';
import 'sfx.dart';
import 'theme.dart';
import 'widgets.dart';

const kTrackCustom = 'custom';

// ───────────────────────── exam profiles ─────────────────────────
/// How the mock exam of a course works. Weights are keyed by domain order (1..6), see domainStats in study.dart.
class ExamProfile {
  final int questions, minutes;
  final double pass; // percent
  final Map<int, int> weights;

  /// Question types allowed in the exam. null = every type.
  final Set<String>? types;
  const ExamProfile({required this.questions, required this.minutes, required this.pass, required this.weights, this.types});
}

/// CCNP ENCOR 350-401: about 100 questions in 120 minutes.
const kEncorExam = ExamProfile(
  questions: 100,
  minutes: 120,
  pass: 82.5,
  weights: {1: 15, 2: 10, 3: 30, 4: 10, 5: 20, 6: 15},
);

/// CCBA: 130 single-choice questions in 180 minutes.
/// Domain order: 1 RADD, 2 EC, 3 RLCM, 4 BAPM, 5 SA, 6 SE.
const kCcbaExam = ExamProfile(
  questions: 130,
  minutes: 180,
  pass: 82.5,
  weights: {1: 32, 2: 20, 3: 18, 4: 12, 5: 12, 6: 6},
  types: {'multiple_choice'},
);

ExamProfile examProfileFor(String track) => track == 'ccba' ? kCcbaExam : kEncorExam;

// ───────────────────────── track list ─────────────────────────
class Track {
  final String id, title, sub;
  final IconData icon;
  final Color color, shadow;

  /// true = lessons come bundled inside the app (assets/courses/<id>/*.json).
  final bool bundled;
  const Track(this.id, this.title, this.sub, this.icon, this.color, this.shadow, this.bundled);
}

const kTracks = [
  Track('encor', 'CCNP ENCOR', 'Cisco 350-401 · Enterprise Core', Icons.router_rounded, AppColors.primary, AppColors.primaryShadow, true),
  Track('ccba', 'CCBA', 'IIBA · Business Analysis (BABOK)', Icons.business_center_rounded, AppColors.success, AppColors.successShadow, true),
  Track(kTrackCustom, 'Custom', 'Import your own JSON files', Icons.edit_note_rounded, AppColors.streak, AppColors.streakShadow, false),
];

Track trackOf(String id) => kTracks.firstWhere((t) => t.id == id, orElse: () => kTracks.last);

/// The course the user picked ('' = not chosen yet). Stored in Hive box 'stats', key 'x_track' (included in Backup).
class TrackNotifier extends Notifier<String> {
  Box get _box => Hive.box('stats');

  @override
  String build() {
    final v = _box.get('x_track');
    return v is String ? v : '';
  }

  void choose(String id) {
    _box.put('x_track', id);
    state = id;
  }
}

final trackProvider = NotifierProvider<TrackNotifier, String>(TrackNotifier.new);

// ───────────────────────── bundled courses ─────────────────────────
/// Courses shipped inside the app: every .json in assets/courses/<track>/ is merged into one course.
class Bundled {
  static final Map<String, Course> byTrack = {};

  static Future<void> load() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final all = manifest.listAssets();
      for (final t in kTracks) {
        if (!t.bundled) continue;
        final files = all.where((a) => a.startsWith('assets/courses/${t.id}/') && a.toLowerCase().endsWith('.json')).toList()..sort();
        final chapters = <Chapter>[];
        final glossary = <GlossaryItem>[];
        final seen = <String>{};
        var title = '';
        for (final f in files) {
          try {
            final j = jsonDecode(await rootBundle.loadString(f));
            if (j is! Map) continue;
            final c = Course.fromJson(Map<String, dynamic>.from(j));
            if (title.isEmpty) title = c.title;
            chapters.addAll(c.chapters);
            for (final g in c.glossary) {
              if (seen.add(g.term.toLowerCase())) glossary.add(g);
            }
          } catch (_) {
            // a broken bundled file is skipped, the others still load
          }
        }
        if (chapters.isNotEmpty) {
          byTrack[t.id] = Course(id: t.id, title: title.isEmpty ? t.title : title, chapters: chapters, glossary: glossary);
        }
      }
    } catch (_) {}
  }
}

/// Makes courseProvider follow the chosen course: bundled files for ENCOR / CCBA, imported files for Custom.
Override courseOverride() => courseProvider.overrideWith((ref) {
      final t = ref.watch(trackProvider);
      if (t.isEmpty || t == kTrackCustom) {
        return AsyncData<Course?>(mergeCourse(ref.watch(packsProvider), ref.watch(foldersProvider)));
      }
      return AsyncData<Course?>(Bundled.byTrack[t]);
    });

// ───────────────────────── screens ─────────────────────────
/// "What do you want to learn?" First = shown once at the very first launch (no back button).
class TrackPickerScreen extends ConsumerWidget {
  final bool first;
  const TrackPickerScreen({super.key, this.first = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = ref.watch(trackProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28), children: [
              if (!first)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 28, color: Color(0xFFAFAFAF)),
                    onPressed: () => Navigator.pop(context),
                  ),
                )
              else
                const SizedBox(height: 24),
              const Center(child: DuckView(size: 120)),
              const SizedBox(height: 10),
              const Center(
                child: Text('What do you want to learn?',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text('You can switch any time. Your XP, streak and duck stay with you.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 22),
              for (final t in kTracks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PressScale(
                    scale: 0.98,
                    onTap: () {
                      Sfx.play('tap');
                      ref.read(trackProvider.notifier).choose(t.id);
                      if (!first && Navigator.canPop(context)) Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: cur == t.id
                          ? duoCard(border: t.color, fill: AppColors.tint, shadow: t.shadow)
                          : duoCard(border: AppColors.line),
                      child: Row(children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(color: t.color, borderRadius: BorderRadius.circular(16)),
                          child: Icon(t.icon, color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
                            Text(t.sub, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
                            if (t.bundled && Bundled.byTrack[t.id] == null)
                              const Text('No lessons bundled yet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.error)),
                          ]),
                        ),
                        if (cur == t.id) const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Shown when the chosen course has no bundled JSON files yet.
class NoContentScreen extends ConsumerWidget {
  const NoContentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trackOf(ref.watch(trackProvider));
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const DuckView(size: 130),
              const SizedBox(height: 16),
              Text('No lessons for ${t.title} yet',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 8),
              Text('Put the course JSON files in assets/courses/${t.id}/ and rebuild the app, or choose another course.',
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              SizedBox(
                width: 240,
                child: Button3D(
                  label: 'Change course',
                  onPressed: () => Navigator.push(context, slideUpRoute(const TrackPickerScreen())),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
