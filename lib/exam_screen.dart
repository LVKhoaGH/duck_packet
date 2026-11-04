import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bag.dart';
import 'duck.dart';
import 'extras.dart';
import 'game_session_screen.dart';
import 'history.dart';
import 'i18n.dart';
import 'models.dart';
import 'providers.dart';
import 'sfx.dart';
import 'study.dart';
import 'theme.dart';
import 'widgets.dart';

/// Share of the exam per domain (ENCOR 350-401 blueprint). Groups without a domain number weigh 10.
const kExamWeight = {1: 15, 2: 10, 3: 30, 4: 10, 5: 20, 6: 15};

/// Pass mark in percent (the real exam does not publish a fixed cut score, so this is only a target).
const kExamPass = 82;

/// Selectable exam sizes. Time = 1.2 minutes per question (100 questions = 120 minutes).
const kExamSizes = [30, 60, 100];

int examMinutes(int n) => (n * 6 / 5).round();

class _ExamItem {
  final Question q;
  final String domain;
  bool? ok; // null = not graded yet
  _ExamItem(this.q, this.domain);
}

int _available(Course c) => domainStats(c).fold<int>(0, (a, g) => a + g.qs.length);

/// Picks questions per domain by weight, fills the rest randomly, then shuffles.
List<_ExamItem> _buildExam(Course c, int n) {
  final rnd = Random();
  final groups = domainStats(c);
  if (groups.isEmpty) return [];
  final sumW = groups.fold<int>(0, (a, g) => a + (kExamWeight[g.order] ?? 10));
  final picked = <_ExamItem>[];
  final used = <Question>{};
  for (final g in groups) {
    final w = kExamWeight[g.order] ?? 10;
    final want = (n * w / sumW).round();
    final pool = List<Question>.of(g.qs)..shuffle(rnd);
    for (final q in pool.take(min(want, pool.length))) {
      picked.add(_ExamItem(q, g.title));
      used.add(q);
    }
  }
  if (picked.length < n) {
    final rest = <_ExamItem>[
      for (final g in groups)
        for (final q in g.qs)
          if (!used.contains(q)) _ExamItem(q, g.title),
    ]..shuffle(rnd);
    picked.addAll(rest.take(n - picked.length));
  }
  while (picked.length > n) {
    picked.removeAt(rnd.nextInt(picked.length));
  }
  picked.shuffle(rnd);
  return picked;
}

String _instruction(Question q) {
  switch (q.type) {
    case 'reorder':
      return 'Put them in the right order';
    case 'match_pairs':
      return 'Tap the matching pairs';
    case 'multiple_choice':
      return 'Choose the correct answer';
    case 'categorize':
      return 'Sort into the right group';
    default:
      return 'Complete the code';
  }
}

String _answerText(Question q) {
  switch (q.type) {
    case 'reorder':
      return q.correctOrder.map((i) => q.items[i]).join('  →  ');
    case 'match_pairs':
      return q.pairs.map((p) => '${p.left}  —  ${p.right}').join('\n');
    case 'categorize':
      final groups = <String>[];
      for (final p in q.pairs) {
        if (!groups.contains(p.right)) groups.add(p.right);
      }
      return groups.map((gr) => '$gr: ${q.pairs.where((p) => p.right == gr).map((p) => p.left).join(', ')}').join('\n');
    default:
      return q.correctAnswer;
  }
}

class ExamScreen extends ConsumerStatefulWidget {
  final Course course;
  const ExamScreen({super.key, required this.course});
  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen> {
  int _phase = 0; // 0 setup, 1 running, 2 result
  int _size = 60;
  List<_ExamItem> _items = [];
  int _i = 0;
  bool _ready = false, _correct = false;
  int _left = 0; // seconds
  Timer? _timer;
  int _xp = 0;
  bool _boosted = false;

  List<int> get _sizes {
    final avail = _available(widget.course);
    final l = [for (final s in kExamSizes) if (s <= avail) s];
    if (l.isEmpty && avail > 0) l.add(avail);
    return l;
  }

  @override
  void initState() {
    super.initState();
    final s = _sizes;
    if (s.isNotEmpty) _size = s.contains(60) ? 60 : s.last;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    final items = _buildExam(widget.course, _size);
    if (items.isEmpty) return;
    Sfx.play('tap');
    setState(() {
      _items = items;
      _i = 0;
      _ready = false;
      _correct = false;
      _left = examMinutes(items.length) * 60;
      _phase = 1;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_left <= 1) {
        _finish();
      } else {
        setState(() => _left--);
      }
    });
  }

  void _onAnswer(bool ready, bool correct) {
    if (_ready != ready || _correct != correct) {
      setState(() {
        _ready = ready;
        _correct = correct;
      });
    }
  }

  /// Grades the question on screen. An unanswered question counts as wrong and is not recorded.
  void _commitCurrent() {
    final it = _items[_i];
    if (it.ok != null) return;
    if (_ready) {
      it.ok = _correct;
      ref.read(studyProvider.notifier).record(qidOf(it.q), _correct);
      ref.read(historyProvider.notifier).addAnswer(_correct);
    } else {
      it.ok = false;
    }
  }

  void _next() {
    Sfx.play('tap');
    _commitCurrent();
    if (_i + 1 >= _items.length) {
      _finish();
    } else {
      setState(() {
        _i++;
        _ready = false;
        _correct = false;
      });
    }
  }

  void _finish() {
    if (_phase != 1) return;
    _timer?.cancel();
    _commitCurrent();
    for (final it in _items) {
      it.ok ??= false;
    }
    final pct = _pct;
    final mult = ref.read(bagProvider.notifier).consumeBoost();
    _boosted = mult > 1;
    _xp = (pct >= kExamPass ? 30 : 15) * mult;
    ref.read(statsProvider.notifier).completeNode('practice', xp: _xp, markNode: false);
    ref.read(extrasProvider.notifier).addXp(_xp);
    ref.read(historyProvider.notifier).addXp(_xp);
    Sfx.play(pct >= kExamPass ? 'success' : 'wrong');
    Sfx.buzz(HapticFeedback.mediumImpact);
    setState(() => _phase = 2);
  }

  int get _correctCount => _items.where((e) => e.ok == true).length;
  int get _pct => _items.isEmpty ? 0 : (_correctCount * 100 / _items.length).round();

  Future<void> _confirmQuit() async {
    final quit = await showQuitSheet(context);
    if (quit == true && mounted) Navigator.pop(context);
  }

  String _clock(int s) {
    final m = s ~/ 60, r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  // ───────────────────────── setup ─────────────────────────
  Widget _setup() {
    final groups = domainStats(widget.course);
    final avail = _available(widget.course);
    final sizes = _sizes;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.close_rounded, size: 30, color: Color(0xFFAFAFAF)), onPressed: () => Navigator.pop(context)),
        ]),
        const Center(child: DuckView(size: 110)),
        const SizedBox(height: 8),
        const Center(child: Text('Mock exam', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.ink))),
        const SizedBox(height: 6),
        const Center(
          child: Text('Mixed by domain weight, timed, no answers until the end.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 20),
        if (avail == 0)
          const Center(child: Text('Import a course with questions first.', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700)))
        else ...[
          for (final s in sizes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PressScale(
                scale: 0.98,
                onTap: () {
                  Sfx.play('tap');
                  setState(() => _size = s);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: _size == s
                      ? duoCard(border: AppColors.primary, fill: AppColors.tint, shadow: AppColors.primaryShadow)
                      : duoCard(),
                  child: Row(children: [
                    Icon(Icons.timer_rounded, color: _size == s ? AppColors.primary : AppColors.locked),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('$s questions',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    ),
                    Text('${examMinutes(s)} min', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black45)),
                  ]),
                ),
              ),
            ),
          const SizedBox(height: 10),
          const Text('Question bank', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: duoCard(),
            child: Column(children: [
              for (final g in groups)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text(g.title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink))),
                    Text('${g.qs.length}', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black45)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          Text('Pass mark: $kExamPass%. You cannot go back to a question.',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38)),
          const SizedBox(height: 20),
        ],
        Button3D(label: 'Start exam', onPressed: avail == 0 ? null : _start),
      ]),
    );
  }

  // ───────────────────────── running ─────────────────────────
  Widget _run() {
    final it = _items[_i];
    final q = it.q;
    final last = _i + 1 >= _items.length;
    final low = _left <= 300;
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 16, 6),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.close_rounded, size: 30, color: Color(0xFFAFAFAF)), onPressed: _confirmQuit),
            Expanded(child: ProgressBar3D(_i / _items.length, track: AppColors.line)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: low ? const Color(0xFFFFE5E6) : AppColors.tint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.timer_rounded, size: 18, color: low ? AppColors.error : AppColors.primaryShadow),
                const SizedBox(width: 4),
                Text(_clock(_left),
                    style: TextStyle(fontWeight: FontWeight.w700, color: low ? AppColors.error : AppColors.primaryShadow)),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: KeyedSubtree(
              key: ValueKey(_i),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Question ${_i + 1} of ${_items.length}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black38)),
                const SizedBox(height: 4),
                Text(_instruction(q), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: duoCard(border: AppColors.line, shadow: Colors.transparent),
                  child: Text(q.prompt, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
                ),
                const SizedBox(height: 22),
                if (q.type == 'reorder')
                  ReorderQuestion(q: q, onAnswer: _onAnswer)
                else if (q.type == 'match_pairs')
                  MatchQuestion(q: q, onAnswer: _onAnswer)
                else if (q.type == 'fill_code')
                  FillCodeQuestion(q: q, onAnswer: _onAnswer)
                else if (q.type == 'multiple_choice')
                  MultipleChoiceQuestion(q: q, onAnswer: _onAnswer)
                else if (q.type == 'categorize')
                  CategorizeQuestion(q: q, onAnswer: _onAnswer)
                else
                  Text('Unsupported question type: ${q.type}'),
              ]),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line, width: 2))),
          child: Row(children: [
            SizedBox(
              width: 110,
              child: Button3D(
                label: 'Skip',
                color: AppColors.locked,
                shadow: AppColors.lockedShadow,
                onPressed: () {
                  // skip = leave unanswered (counts as wrong)
                  setState(() {
                    _ready = false;
                    _correct = false;
                  });
                  _next();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Button3D(label: last ? 'Finish' : 'Next', onPressed: _ready ? _next : null)),
          ]),
        ),
      ]),
    );
  }

  // ───────────────────────── result ─────────────────────────
  Widget _result() {
    final pass = _pct >= kExamPass;
    final byDomain = <String, List<_ExamItem>>{};
    for (final it in _items) {
      byDomain.putIfAbsent(it.domain, () => []).add(it);
    }
    final wrong = _items.where((e) => e.ok != true).toList();
    return Stack(children: [
      SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 28), children: [
          Center(child: DuckView(size: 130, mood: pass ? DuckMood.happy : DuckMood.confused)),
          const SizedBox(height: 8),
          Center(
            child: Text(pass ? 'Exam passed!' : 'Not there yet',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: pass ? AppColors.success : AppColors.error)),
          ),
          const SizedBox(height: 4),
          Center(child: Text('$_pct%', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: AppColors.ink))),
          Center(
            child: Text('$_correctCount / ${_items.length} correct  ·  pass mark $kExamPass%',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black45)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(_boosted ? '+$_xp XP (x2 boost!)' : '+$_xp XP',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.streakShadow)),
          ),
          const SizedBox(height: 22),
          const Text('By domain', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: duoCard(),
            child: Column(children: [
              for (final e in byDomain.entries)
                Builder(builder: (_) {
                  final c = e.value.where((x) => x.ok == true).length;
                  final t = e.value.length;
                  final v = t == 0 ? 0.0 : c / t;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink))),
                        Text('${(v * 100).round()}%  ($c/$t)', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black45)),
                      ]),
                      const SizedBox(height: 6),
                      ProgressBar3D(v, track: AppColors.line, fill: v * 100 >= kExamPass ? AppColors.success : AppColors.error),
                    ]),
                  );
                }),
            ]),
          ),
          if (wrong.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text('Review mistakes (${wrong.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 8),
            for (final it in wrong)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: duoCard(border: AppColors.error, shadow: AppColors.errorShadow),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it.domain, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38)),
                    const SizedBox(height: 4),
                    Text(it.q.prompt, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 8),
                    const Text('Correct solution:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
                    Text(_answerText(it.q), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    Text(it.q.explanation, style: const TextStyle(color: Colors.black54, height: 1.4)),
                  ]),
                ),
              ),
          ],
          const SizedBox(height: 14),
          Button3D(label: 'Done', onPressed: () => Navigator.pop(context)),
        ]),
      ),
      if (pass) const Positioned.fill(child: IgnorePointer(child: Confetti())),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase != 1,
      onPopInvoked: (didPop) {
        if (!didPop && _phase == 1) _confirmQuit();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _phase == 0 ? _setup() : (_phase == 1 ? _run() : _result()),
      ),
    );
  }
}
