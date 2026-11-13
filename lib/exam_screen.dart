import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cli_engine.dart';
import 'lab_screen.dart';
import 'multi_select_question.dart';
import 'question_extras.dart';
import 'duck.dart';
import 'game_session_screen.dart';
import 'history.dart';
import 'i18n.dart';
import 'models.dart';
import 'sfx.dart';
import 'study.dart';
import 'theme.dart';
import 'tracks.dart';
import 'widgets.dart';

/// Share of the exam per domain (ENCOR 350-401 blueprint). Groups without a domain number weigh 10.
const kExamWeight = {1: 15, 2: 10, 3: 30, 4: 10, 5: 20, 6: 15};

/// Pass mark in percent (about 825 / 1000 on the real exam). Only applies to the full exam.
const double kExamPass = 82.5;

/// Selectable exam sizes. Time = 1.2 minutes per question (100 questions = 120 minutes).
const kExamSizes = [30, 60, 100];

/// Time scales with the course: ENCOR 1.2 min per question, CCBA 180 / 130 min per question.
int examMinutes(int n, ExamProfile pf) => (n * pf.minutes / pf.questions).round();

class _ExamItem {
  final Question q;
  final String domain;
  bool? ok; // null = not graded yet
  _ExamItem(this.q, this.domain);
}

/// Keeps only the question types this course's exam allows (CCBA = single choice only).
List<Question> _ok(Iterable<Question> qs, ExamProfile pf) =>
    pf.types == null ? qs.toList() : qs.where((q) => pf.types!.contains(q.type)).toList();

int _available(Course c, ExamProfile pf) => domainStats(c).fold<int>(0, (a, g) => a + _ok(g.qs, pf).length);

/// Picks questions per domain by weight, fills the rest randomly, then shuffles.
List<_ExamItem> _buildExam(Course c, int n, ExamProfile pf) {
  final rnd = Random();
  final groups = domainStats(c).where((g) => _ok(g.qs, pf).isNotEmpty).toList();
  if (groups.isEmpty) return [];
  final sumW = groups.fold<int>(0, (a, g) => a + (pf.weights[g.order] ?? 10));
  final picked = <_ExamItem>[];
  final used = <Question>{};
  for (final g in groups) {
    final w = pf.weights[g.order] ?? 10;
    final want = (n * w / sumW).round();
    final pool = _ok(g.qs, pf)..shuffle(rnd);
    for (final q in pool.take(min(want, pool.length))) {
      picked.add(_ExamItem(q, g.title));
      used.add(q);
    }
  }
  if (picked.length < n) {
    final rest = <_ExamItem>[
      for (final g in groups)
        for (final q in _ok(g.qs, pf))
          if (!used.contains(q)) _ExamItem(q, g.title),
    ]..shuffle(rnd);
    picked.addAll(rest.take(n - picked.length));
  }
  while (picked.length > n) {
    picked.removeAt(rnd.nextInt(picked.length));
  }
  picked.shuffle(rnd);
  // Like the real exam: simulation labs come first.
  return [...picked.where((x) => x.q.type == 'lab'), ...picked.where((x) => x.q.type != 'lab')];
}

/// Practice inside one domain or one chapter: random questions from that pool only.
List<_ExamItem> _buildScoped(List<Question> pool, String label, int n) {
  final l = List<Question>.of(pool)..shuffle(Random());
  final picked = <_ExamItem>[for (final q in l.take(min(n, l.length))) _ExamItem(q, label)];
  return [...picked.where((x) => x.q.type == 'lab'), ...picked.where((x) => x.q.type != 'lab')];
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
    case 'multi_select':
      return 'Select all that apply';
    case 'lab':
      return 'Complete the lab';
    case 'show_output':
      return 'Read the output';
    case 'route_predict':
      return 'Predict the route';
    case 'topology_drag':
      return 'Drag labels onto the diagram';
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
    case 'multi_select':
      return q.correctAnswers.join('\n');
    case 'lab':
      return labSolutionText(q.lab);
    case 'topology_drag':
      return extraAnswerText(q);
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
  int _size = 100;
  int _min = 120; // minutes
  bool _timed = true, _minTouched = false;
  int _dom = -1, _chap = -1; // scope: both -1 = full exam
  List<_ExamItem> _items = [];
  int _i = 0;
  bool _ready = false, _correct = false;
  int _left = 0; // seconds
  Timer? _timer;

  List<DomainStat> get _groups => domainStats(widget.course);
  List<Chapter> get _chapters => [for (final ch in widget.course.chapters) if (ch.nodes.any((n) => n.questions.isNotEmpty)) ch];
  bool get _graded => _dom < 0 && _chap < 0;
  ExamProfile get _pf => examProfileFor(ref.read(trackProvider));

  int get _poolSize {
    if (_dom >= 0 && _dom < _groups.length) return _ok(_groups[_dom].qs, _pf).length;
    if (_chap >= 0 && _chap < _chapters.length) {
      return _ok([for (final n in _chapters[_chap].nodes) ...n.questions], _pf).length;
    }
    return _available(widget.course, _pf);
  }

  int get _maxQ => min(_poolSize, _pf.questions);

  void _fit() {
    final mx = _maxQ;
    final mn = min(5, mx);
    if (_size > mx) _size = mx;
    if (_size < mn) _size = mn;
    if (!_minTouched) _min = max(1, examMinutes(_size, _pf));
  }

  @override
  void initState() {
    super.initState();
    _size = _pf.questions;
    _fit();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<_ExamItem> _buildItems() {
    if (_dom >= 0 && _dom < _groups.length) {
      final g = _groups[_dom];
      return _buildScoped(_ok(g.qs, _pf), g.title, _size);
    }
    if (_chap >= 0 && _chap < _chapters.length) {
      final ch = _chapters[_chap];
      return _buildScoped(_ok([for (final n in ch.nodes) ...n.questions], _pf), ch.title, _size);
    }
    return _buildExam(widget.course, _size, _pf);
  }

  void _start() {
    final items = _buildItems();
    if (items.isEmpty) return;
    Sfx.play('tap');
    setState(() {
      _items = items;
      _i = 0;
      _ready = false;
      _correct = false;
      _left = _min * 60;
      _phase = 1;
    });
    if (_timed) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_left <= 1) {
          _finish();
        } else {
          setState(() => _left--);
        }
      });
    }
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
    final good = _ratio >= _pf.pass;
    Sfx.play(good ? 'success' : 'wrong');
    Sfx.buzz(HapticFeedback.mediumImpact);
    setState(() => _phase = 2);
  }

  int get _correctCount => _items.where((e) => e.ok == true).length;
  double get _ratio => _items.isEmpty ? 0.0 : _correctCount * 100 / _items.length;
  int get _pct => _ratio.round();

  Future<void> _confirmQuit() async {
    final quit = await showQuitSheet(context);
    if (quit == true && mounted) Navigator.pop(context);
  }

  String _clock(int s) {
    final m = s ~/ 60, r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  // ───────────────────────── setup ─────────────────────────
  Widget _sec(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
      );

  Widget _setup() {
    final groups = _groups;
    final chaps = _chapters;
    final avail = _available(widget.course, _pf);
    final mx = _maxQ;
    final mn = min(5, mx);
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
        Row(children: [
          IconButton(icon: Icon(Icons.close_rounded, size: 30, color: AppColors.icon), onPressed: () => Navigator.pop(context)),
        ]),
        const Center(child: DuckView(size: 110)),
        const SizedBox(height: 8),
        Center(child: Text('Mock exam', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.ink))),
        const SizedBox(height: 6),
        Center(
          child: Text('Timed, no answers until the end.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.mid, fontWeight: FontWeight.w700)),
        ),
        if (avail == 0) ...[
          const SizedBox(height: 20),
          Center(child: Text('Import a course with questions first.', style: TextStyle(color: AppColors.sub, fontWeight: FontWeight.w700))),
        ] else ...[
          _sec('Scope'),
          Wrap(spacing: 8, runSpacing: 4, children: [
            ChoiceChip(
              label: const Text('Full exam'),
              selected: _graded,
              selectedColor: AppColors.tint,
              onSelected: (_) => setState(() {
                _dom = -1;
                _chap = -1;
                _fit();
              }),
            ),
            for (var i = 0; i < groups.length; i++)
              ChoiceChip(
                label: Text(groups[i].title),
                selected: _dom == i,
                selectedColor: AppColors.tint,
                onSelected: (_) => setState(() {
                  _dom = i;
                  _chap = -1;
                  _fit();
                }),
              ),
          ]),
          const SizedBox(height: 8),
          DropdownButton<int>(
            isExpanded: true,
            value: _chap >= 0 && _chap < chaps.length ? _chap : null,
            hint: const Text('Or pick one chapter'),
            items: [for (var i = 0; i < chaps.length; i++) DropdownMenuItem<int>(value: i, child: Text(chaps[i].title))],
            onChanged: (v) => setState(() {
              _chap = v ?? -1;
              _dom = -1;
              _fit();
            }),
          ),
          _sec('Questions'),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            decoration: duoCard(),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.quiz_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(child: Text('$_size of $_poolSize available', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink))),
              ]),
              if (mx > mn)
                Slider(
                  value: _size.toDouble(),
                  min: mn.toDouble(),
                  max: mx.toDouble(),
                  divisions: mx - mn,
                  label: '$_size',
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() {
                    _size = v.round();
                    _fit();
                  }),
                ),
              Wrap(spacing: 8, children: [
                for (final p in {30, 60, _pf.questions})
                  if (p <= mx)
                    ActionChip(
                      label: Text('$p'),
                      onPressed: () => setState(() {
                        _size = p;
                        _fit();
                      }),
                    ),
              ]),
              const SizedBox(height: 6),
            ]),
          ),
          _sec('Time'),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            decoration: duoCard(),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.timer_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(child: Text('Timer', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink))),
                Switch(value: _timed, onChanged: (v) => setState(() => _timed = v)),
              ]),
              if (_timed)
                Row(children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    onPressed: _min <= 5
                        ? null
                        : () => setState(() {
                              _min = max(5, _min - 5);
                              _minTouched = true;
                            }),
                  ),
                  Expanded(
                    child: Center(
                      child: Text('$_min min', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    onPressed: _min >= 300
                        ? null
                        : () => setState(() {
                              _min = min(300, _min + 5);
                              _minTouched = true;
                            }),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _minTouched = false;
                      _fit();
                    }),
                    child: const Text('Auto'),
                  ),
                ]),
            ]),
          ),
          const SizedBox(height: 10),
          Text(
              _graded
                  ? 'Full exam follows the real domain weights. Pass mark: ${_pf.pass}%. You cannot go back to a question.'
                  : 'Practice mode: only this scope, no pass mark. You cannot go back to a question.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.faint)),
          const SizedBox(height: 4),
          Text('Mock exams give no XP and do not touch your streak.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.faint)),
          const SizedBox(height: 20),
        ],
        Button3D(label: 'Start exam', onPressed: avail == 0 || _poolSize == 0 ? null : _start),
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
            IconButton(icon: Icon(Icons.close_rounded, size: 30, color: AppColors.icon), onPressed: _confirmQuit),
            Expanded(child: ProgressBar3D(_i / _items.length, track: AppColors.line)),
            if (_timed) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: low ? AppColors.errorTint : AppColors.tint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.timer_rounded, size: 18, color: low ? AppColors.error : AppColors.primaryShadow),
                const SizedBox(width: 4),
                Text(_clock(_left),
                    style: TextStyle(fontWeight: FontWeight.w700, color: low ? AppColors.error : AppColors.primaryShadow)),
              ]),
            ),
            ],
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: KeyedSubtree(
              key: ValueKey(_i),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Question ${_i + 1} of ${_items.length}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.faint)),
                const SizedBox(height: 4),
                Text(_instruction(q), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: duoCard(border: AppColors.line, shadow: Colors.transparent),
                  child: Text(q.prompt, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
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
                else if (q.type == 'multi_select')
                  MultiSelectQuestion(q: q, onAnswer: _onAnswer)
                else if (q.type == 'lab')
                  LabQuestion(q: q, onAnswer: _onAnswer)
                else if (q.type == 'show_output')
                  ShowOutputQuestion(q: q, onAnswer: _onAnswer)
                else if (q.type == 'route_predict')
                  RoutePredictQuestion(q: q, onAnswer: _onAnswer)
                else if (q.type == 'topology_drag')
                  TopologyDragQuestion(q: q, onAnswer: _onAnswer)
                else
                  Text('Unsupported question type: ${q.type}'),
              ]),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.line, width: 2))),
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
    final pass = _ratio >= _pf.pass;
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
            child: Text(_graded ? (pass ? 'Exam passed!' : 'Not there yet') : (pass ? 'Great work!' : 'Keep practicing'),
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: pass ? AppColors.success : AppColors.error)),
          ),
          const SizedBox(height: 4),
          Center(child: Text('$_pct%', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: AppColors.ink))),
          Center(
            child: Text(_graded ? '$_correctCount / ${_items.length} correct  ·  pass mark ${_pf.pass}%' : '$_correctCount / ${_items.length} correct',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.sub)),
          ),
          const SizedBox(height: 22),
          Text('By domain', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
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
                        Expanded(child: Text(e.key, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink))),
                        Text('${(v * 100).round()}%  ($c/$t)', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.sub)),
                      ]),
                      const SizedBox(height: 6),
                      ProgressBar3D(v, track: AppColors.line, fill: v * 100 >= _pf.pass ? AppColors.success : AppColors.error),
                    ]),
                  );
                }),
            ]),
          ),
          if (wrong.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text('Review mistakes (${wrong.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 8),
            for (final it in wrong)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: duoCard(border: AppColors.error, shadow: AppColors.errorShadow),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it.domain, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.faint)),
                    const SizedBox(height: 4),
                    Text(it.q.prompt, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 8),
                    const Text('Correct solution:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
                    Text(_answerText(it.q), style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    Text(it.q.explanation, style: TextStyle(color: AppColors.mid, height: 1.4)),
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
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _phase == 1) _confirmQuit();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: _phase == 0 ? _setup() : (_phase == 1 ? _run() : _result()),
      ),
    );
  }
}
