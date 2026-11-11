import 'dart:math';
import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_chat.dart';
import 'bag.dart';
import 'duck.dart';
import 'lab_screen.dart';
import 'multi_select_question.dart';
import 'question_extras.dart';
import 'cli_engine.dart';
import 'extras.dart';
import 'history.dart';
import 'models.dart';
import 'providers.dart';
import 'quests.dart';
import 'quests_screen.dart';
import 'sfx.dart';
import 'streak_screen.dart';
import 'study.dart';
import 'theme.dart';
import 'widgets.dart';

typedef AnswerCallback = void Function(bool ready, bool correct);

const _praise = ['Correct!', 'Nice!', 'Awesome!', 'Perfect!'];

/// node: a monster (one map node) | boss: end of chapter | practice/review/mistakes: Practice hub sessions.
enum SessionMode { node, boss, practice, review, mistakes }

class GameSessionScreen extends ConsumerStatefulWidget {
  final CourseNode node; // for a boss, node.id is "boss:<chapterId>"
  final SessionMode mode;
  const GameSessionScreen({super.key, required this.node, this.mode = SessionMode.node});
  @override
  ConsumerState<GameSessionScreen> createState() => _GameSessionScreenState();
}

class _GameSessionScreenState extends ConsumerState<GameSessionScreen> {
  int _index = 0, _combo = 0, _bestCombo = 0, _mistakes = 0, _shake = 0;
  bool _ready = false, _correct = false, _finished = false, _firstToday = false, _passed = false;
  int _acc = 0, _earnedXp = 0;
  bool _boosted = false;
  final Stopwatch _sw = Stopwatch()..start();
  final List<String> _qids = [];
  final List<bool> _oks = [];
  int _labsPassed = 0;
  MetaOutcome? _meta;

  bool get _isBoss => widget.mode == SessionMode.boss;
  bool get _isNode => widget.mode == SessionMode.node;

  // Wrong answers are queued again at the end (max 2 retries per question). No retries on a boss.
  late final List<Question> _queue = List.of(widget.node.questions);
  final Map<Question, int> _retries = {};
  int _correctCount = 0;
  int get _total => widget.node.questions.length;

  void _onAnswer(bool ready, bool correct) {
    if (_ready != ready || _correct != correct) {
      setState(() {
        _ready = ready;
        _correct = correct;
      });
    }
  }

  Future<void> _confirmQuit() async {
    final quit = await showQuitSheet(context);
    if (quit == true && mounted) Navigator.pop(context);
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
        return groups
            .map((gr) => '$gr: ${q.pairs.where((p) => p.right == gr).map((p) => p.left).join(', ')}')
            .join('\n');
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

  Future<void> _check() async {
    final q = _queue[_index];
    final ok = _correct;
    final isRetry = (_retries[q] ?? 0) > 0;
    ref.read(studyProvider.notifier).record(qidOf(q), ok, retry: isRetry);
    if (!isRetry) {
      ref.read(historyProvider.notifier).addAnswer(ok);
      _qids.add(qidOf(q));
      _oks.add(ok);
      if (ok && q.type == 'lab') _labsPassed++;
    }

    if (ok) {
      _correctCount++;
      _combo++;
      _bestCombo = max(_bestCombo, _combo);
      Sfx.play('correct');
    } else {
      _combo = 0;
      _mistakes++;
      Sfx.play('wrong');
      Sfx.buzz(HapticFeedback.heavyImpact);
      setState(() => _shake++);
    }

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      clipBehavior: Clip.none,
      backgroundColor: ok ? AppColors.success : AppColors.error,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _sheet(ctx, q, ok),
    );
    if (!mounted) return;

    if (!ok && !_isBoss && (_retries[q] ?? 0) < 2) {
      _retries[q] = (_retries[q] ?? 0) + 1;
      _queue.add(q);
    }

    if (_index + 1 >= _queue.length) {
      _finish();
    } else {
      setState(() {
        _index++;
        _ready = false;
        _correct = false;
      });
    }
  }

  void _finish() {
    final total = _total;
    _firstToday = !ref.read(statsProvider).practicedToday;
    _acc = ((total - min(_mistakes, total)) / total * 100).round();
    final stats = ref.read(statsProvider.notifier);
    final study = ref.read(studyProvider.notifier);
    final mult = ref.read(bagProvider.notifier).consumeBoost(); // 2 while an XP x2 item is active
    _boosted = mult > 1;

    if (_isNode) {
      _earnedXp = 10 * mult;
      stats.completeNode(widget.node.id, xp: _earnedXp);
      study.setBest(widget.node.id, _acc);
    } else if (_isBoss) {
      _passed = _acc >= kBossPass;
      _earnedXp = (_passed ? 30 : 10) * mult;
      stats.completeNode(widget.node.id, xp: _earnedXp, markNode: _passed);
      study.setBest(widget.node.id, _acc);
    } else {
      _earnedXp = 5 * mult;
      stats.completeNode('practice', xp: _earnedXp, markNode: false);
    }
    ref.read(extrasProvider.notifier).addXp(_earnedXp);
    ref.read(historyProvider.notifier).addXp(_earnedXp);
    // nhiệm vụ ngày + huy hiệu + thưởng bất ngờ
    _meta = ref.read(metaProvider.notifier).onSessionDone(SessionResult(
      mode: widget.mode.name,
      total: total,
      mistakes: min(_mistakes, total),
      acc: _acc,
      seconds: _sw.elapsed.inSeconds,
      bestCombo: _bestCombo,
      earnedXp: _earnedXp,
      labsPassed: _labsPassed,
      hour: DateTime.now().hour,
      passed: _isBoss ? _passed : true,
      bossId: widget.node.id,
      qids: List<String>.of(_qids),
      oks: List<bool>.of(_oks),
    ));
    Sfx.play('success');
    Sfx.buzz(HapticFeedback.mediumImpact);
    setState(() => _finished = true);
  }

  String _aiContext(Question q, bool ok) =>
      'Question: ${q.prompt}\nCorrect answer: ${_answerText(q)}\nExplanation: ${q.explanation}\n'
      'The student answered ${ok ? "correctly" : "incorrectly"}.';

  Widget _sheet(BuildContext ctx, Question q, bool ok) {
    final dark = ok ? AppColors.successShadow : AppColors.errorShadow;
    final maxH = MediaQuery.of(ctx).size.height * 0.5;
    return Stack(clipBehavior: Clip.none, children: [
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, color: Colors.white, size: 34),
                    const SizedBox(width: 10),
                    Text(ok ? _praise[_index % _praise.length] : 'Incorrect',
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                  ]),
                  if (ok && _combo >= 2) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const SvgIcon('ic_fire', size: 18),
                      const SizedBox(width: 4),
                      Text('$_combo in a row', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ]),
                  ],
                  if (!ok) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Correct solution:',
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(_answerText(q), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    Text(q.explanation, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showAiSheet(ctx, contextText: _aiContext(q, ok)),
                icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                label: const Text('Ask AI about this',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            Button3D(
              label: ok ? 'Continue' : 'Got it',
              color: Colors.white,
              shadow: Colors.black26,
              textColor: dark,
              onPressed: () => Navigator.pop(ctx),
            ),
          ]),
        ),
      ),
      // Duck peeks over the top edge of the sheet.
      Positioned(
        top: -50,
        right: 20,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutBack,
          builder: (_, v, c) => Transform.translate(offset: Offset(0, 40 * (1 - v)), child: c),
          child: DuckView(size: 70, mood: ok ? DuckMood.happy : DuckMood.confused),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    if (_finished) return _summary(total);

    final q = _queue[_index];
    final isRetry = _queue.indexOf(q) < _index;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 6),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.close_rounded, size: 30, color: Color(0xFFAFAFAF)), onPressed: _confirmQuit),
              if (_isBoss)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.whatshot_rounded, size: 16, color: Colors.white),
                      SizedBox(width: 2),
                      Text('BOSS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.8)),
                    ]),
                  ),
                ),
              // Boss: HP bar that drains with every correct answer. Others: progress bar.
              Expanded(
                child: _isBoss
                    ? ProgressBar3D(1 - _correctCount / total, track: AppColors.line, fill: AppColors.error)
                    : ProgressBar3D(_correctCount / total, track: AppColors.line),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: _combo >= 2
                    ? Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3D6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const SvgIcon('ic_fire', size: 20),
                            const SizedBox(width: 2),
                            Text('$_combo',
                                style: const TextStyle(color: AppColors.streak, fontWeight: FontWeight.w700, fontSize: 16)),
                          ]),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0.25, 0), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_index),
                  child: Shake(
                    trigger: _shake,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (isRetry) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFFFF3D6), borderRadius: BorderRadius.circular(20)),
                          child: const Text('TRY AGAIN',
                              style: TextStyle(color: AppColors.streak, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.8)),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(_instruction(q), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink)),
                      const SizedBox(height: 16),
                      _PromptBubble(
                        text: q.prompt,
                        mood: _combo >= 3 ? DuckMood.happy : DuckMood.idle,
                      ),
                      const SizedBox(height: 24),
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
            ),
          ),
          // Bottom Action Bar (thumb zone)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line, width: 2))),
            child: Button3D(label: 'Check Answer', onPressed: _ready ? _check : null),
          ),
        ]),
      ),
    );
  }

  Widget _summary(int total) {
    final acc = _acc;
    final lost = _isBoss && !_passed;
    final String title = _isNode
        ? 'Monster defeated!'
        : _isBoss
            ? (_passed ? 'Boss defeated!' : 'Boss survived...')
            : 'Practice complete!';
    final String sub = lost
        ? 'You need $kBossPass% to win. Review and try again!'
        : (_isNode || _isBoss)
            ? widget.node.title
            : 'Great review session';
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Spacer(),
              DuckView(size: 160, mood: lost ? DuckMood.confused : (acc >= 60 ? DuckMood.happy : DuckMood.idle)),
              const SizedBox(height: 16),
              Pop(
                child: Text(title,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: lost ? AppColors.error : AppColors.streak)),
              ),
              const SizedBox(height: 4),
              Text(sub,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black45)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: _Tile(label: 'TOTAL XP', color: AppColors.streak, icon: const Icon(Icons.bolt_rounded, color: AppColors.streak, size: 26), end: _earnedXp, delay: 0)),
                const SizedBox(width: 10),
                Expanded(
                    child: _Tile(
                        label: acc >= 90 ? 'AMAZING' : 'ACCURACY',
                        color: AppColors.success,
                        icon: const Icon(Icons.check_circle, color: AppColors.success, size: 26),
                        end: acc,
                        suffix: '%', delay: 120)),
                const SizedBox(width: 10),
                Expanded(child: _Tile(label: 'BEST COMBO', color: AppColors.error, icon: const SvgIcon('ic_fire', size: 26), end: _bestCombo, delay: 240)),
              ]),
              const SizedBox(height: 18),
              if (_boosted) ...[
                const Pop(
                  child: Text('XP x2 boost!', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.streakShadow, fontSize: 16)),
                ),
                const SizedBox(height: 10),
              ],
              const _GoalLine(),
              const Spacer(),
              Button3D(
                label: lost ? 'Back to map' : 'Continue',
                onPressed: () async {
                  final m = _meta;
                  if (m != null && !m.isEmpty) {
                    _meta = null;
                    await showRewardDialogs(context, ref, m);
                    if (!mounted) return;
                  }
                  if (_firstToday) {
                    Navigator.pushReplacement(context, slideUpRoute(StreakScreen(streak: ref.read(statsProvider).streak)));
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            ]),
          ),
        ),
        if (!lost) const Positioned.fill(child: Confetti()),
      ]),
    );
  }
}

/// Duolingo-style stat tile: colored header band + value.
class _Tile extends StatelessWidget {
  final String label, suffix;
  final Color color;
  final Widget icon;
  final int end, delay;
  const _Tile({required this.label, required this.color, required this.icon, required this.end, this.suffix = '', this.delay = 0});
  @override
  Widget build(BuildContext context) => Pop(
      delay: delay,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(13))),
            child: Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.8)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              icon,
              const SizedBox(width: 4),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: end),
                duration: const Duration(milliseconds: 900),
                builder: (_, v, __) => Text('$v$suffix', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
              ),
            ]),
          ),
        ]),
      ));
}

/// Mascot + speech bubble holding the question prompt.
class _PromptBubble extends StatelessWidget {
  final String text;
  final DuckMood mood;
  const _PromptBubble({required this.text, required this.mood});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 76, child: DuckView(size: 76, mood: mood)),
        const SizedBox(width: 14),
        Expanded(
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: duoCard(border: AppColors.line, shadow: Colors.transparent),
              child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
            ),
            Positioned(
              left: -8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Transform.rotate(
                  angle: pi / 4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        left: BorderSide(color: AppColors.line, width: 2),
                        bottom: BorderSide(color: AppColors.line, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]);
}

// ───────────────────────── reorder (word bank) ─────────────────────────
class ReorderQuestion extends StatefulWidget {
  final Question q;
  final AnswerCallback onAnswer;
  const ReorderQuestion({super.key, required this.q, required this.onAnswer});
  @override
  State<ReorderQuestion> createState() => _ReorderQuestionState();
}

class _ReorderQuestionState extends State<ReorderQuestion> {
  late final List<int> bank; // fixed shuffled order of the word bank
  final List<int> answer = []; // item indexes in the order the user placed them

  @override
  void initState() {
    super.initState();
    bank = List.generate(widget.q.items.length, (i) => i)..shuffle(Random());
  }

  void _report() {
    final full = answer.length == widget.q.items.length;
    var ok = full;
    if (full) {
      for (var i = 0; i < answer.length; i++) {
        if (answer[i] != widget.q.correctOrder[i]) ok = false;
      }
    }
    widget.onAnswer(full, ok);
  }

  void _add(int item) {
    Sfx.play('tap');
    setState(() => answer.add(item));
    _report();
  }

  void _remove(int pos) {
    Sfx.play('tap');
    setState(() => answer.removeAt(pos));
    _report();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.q.items.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var pos = 0; pos < n; pos++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: pos < answer.length
                ? GestureDetector(
                    key: ValueKey('a${answer[pos]}'),
                    onTap: () => _remove(pos),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: duoCard(border: AppColors.primary, fill: AppColors.tint, shadow: AppColors.primaryShadow),
                      child: Row(children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: Text('${pos + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(widget.q.items[answer[pos]],
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        ),
                      ]),
                    ),
                  )
                : Container(
                    key: ValueKey('s$pos'),
                    width: double.infinity,
                    height: 50,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 14),
                    decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(16)),
                    child: Text('${pos + 1}', style: const TextStyle(color: AppColors.locked, fontWeight: FontWeight.w700, fontSize: 18)),
                  ),
          ),
        ),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final i in bank)
          answer.contains(i)
              ? duoChip(widget.q.items[i], ghost: true)
              : PressScale(onTap: () => _add(i), child: duoChip(widget.q.items[i])),
      ]),
    ]);
  }
}

// ───────────────────────── match pairs ─────────────────────────
class MatchQuestion extends StatefulWidget {
  final Question q;
  final AnswerCallback onAnswer;
  const MatchQuestion({super.key, required this.q, required this.onAnswer});
  @override
  State<MatchQuestion> createState() => _MatchQuestionState();
}

class _MatchQuestionState extends State<MatchQuestion> {
  static const _palette = [AppColors.primary, AppColors.streak, AppColors.success, Color(0xFF9B6BFF), AppColors.error, Color(0xFFFF7BAC)];
  late List<int> rightOrder;
  final Map<int, int> matches = {};
  int? selectedLeft;

  @override
  void initState() {
    super.initState();
    rightOrder = List.generate(widget.q.pairs.length, (i) => i)..shuffle(Random());
  }

  void _report() {
    final ready = matches.length == widget.q.pairs.length;
    widget.onAnswer(ready, ready && matches.entries.every((e) => e.key == e.value));
  }

  Color? _colorForLeft(int l) => matches.containsKey(l) ? _palette[l % _palette.length] : null;
  Color? _colorForRight(int r) {
    for (final e in matches.entries) {
      if (e.value == r) return _palette[e.key % _palette.length];
    }
    return null;
  }

  Widget _pill(String text, Color? paired, bool selected, VoidCallback onTap) {
    final deco = paired != null
        ? duoCard(border: paired, fill: paired.withOpacity(0.15))
        : selected
            ? duoCard(border: AppColors.primary, fill: AppColors.tint, shadow: AppColors.primaryShadow)
            : duoCard();
    return GestureDetector(
      onTap: () {
        Sfx.play('tap');
        onTap();
      },
      child: AnimatedScale(
        scale: selected ? 1.04 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(minHeight: 64),
          alignment: Alignment.center,
          decoration: deco,
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pairs = widget.q.pairs;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(children: [
          for (var l = 0; l < pairs.length; l++)
            _pill(pairs[l].left, _colorForLeft(l), selectedLeft == l, () {
              setState(() {
                if (matches.containsKey(l)) {
                  matches.remove(l);
                  selectedLeft = null;
                } else {
                  selectedLeft = l;
                }
              });
              _report();
            }),
        ]),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(children: [
          for (final r in rightOrder)
            _pill(pairs[r].right, _colorForRight(r), false, () {
              if (_colorForRight(r) != null) {
                setState(() => matches.removeWhere((_, v) => v == r));
              } else if (selectedLeft != null) {
                setState(() {
                  matches[selectedLeft!] = r;
                  selectedLeft = null;
                });
              }
              _report();
            }),
        ]),
      ),
    ]);
  }
}

// ───────────────────────── fill code ─────────────────────────
class FillCodeQuestion extends StatefulWidget {
  final Question q;
  final AnswerCallback onAnswer;
  const FillCodeQuestion({super.key, required this.q, required this.onAnswer});
  @override
  State<FillCodeQuestion> createState() => _FillCodeQuestionState();
}

class _FillCodeQuestionState extends State<FillCodeQuestion> {
  String? selected;

  void _pick(String? v) {
    Sfx.play('tap');
    setState(() => selected = v);
    widget.onAnswer(v != null, v == widget.q.correctAnswer);
  }

  Widget _dot(Color c) => Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  @override
  Widget build(BuildContext context) {
    final parts = widget.q.template.split('[BLANK]');
    final blank = DragTarget<String>(
      onAcceptWithDetails: (d) => _pick(d.data),
      builder: (_, cand, __) => GestureDetector(
        onTap: selected == null ? null : () => _pick(null),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: cand.isNotEmpty ? AppColors.primary.withOpacity(0.35) : (selected == null ? Colors.white12 : AppColors.primary.withOpacity(0.25)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.primary, width: cand.isNotEmpty ? 2 : 1),
          ),
          child: Text(selected ?? '          ', style: codeStyle.copyWith(color: Colors.white)),
        ),
      ),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.terminalBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [_dot(AppColors.error), _dot(AppColors.streak), _dot(AppColors.success)]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text.rich(TextSpan(style: codeStyle, children: [
              TextSpan(text: parts.first),
              WidgetSpan(alignment: PlaceholderAlignment.middle, child: blank),
              if (parts.length > 1) TextSpan(text: parts.sublist(1).join('[BLANK]')),
            ])),
          ),
        ]),
      ),
      const SizedBox(height: 24),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final o in widget.q.options)
          if (o == selected)
            duoChip(o, mono: true, ghost: true)
          else
            Draggable<String>(
              data: o,
              feedback: Material(color: Colors.transparent, child: Transform.scale(scale: 1.08, child: duoChip(o, mono: true))),
              childWhenDragging: duoChip(o, mono: true, ghost: true),
              child: PressScale(onTap: () => _pick(o), child: duoChip(o, mono: true)),
            ),
      ]),
    ]);
  }
}


/// Daily-goal progress shown on the summary screen.
class _GoalLine extends ConsumerWidget {
  const _GoalLine();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(extrasProvider);
    final v = (e.todayXp / e.goal).clamp(0.0, 1.0).toDouble();
    return Pop(
      delay: 360,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: duoCard(border: e.goalDone ? AppColors.success : AppColors.line),
        child: Row(children: [
          Icon(e.goalDone ? Icons.check_circle_rounded : Icons.flag_rounded,
              color: e.goalDone ? AppColors.success : AppColors.streak, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.goalDone ? 'Daily goal reached!' : 'Daily goal',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 6),
              ProgressBar3D(v, track: AppColors.line),
            ]),
          ),
          const SizedBox(width: 12),
          Text('${e.todayXp}/${e.goal}', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black45)),
        ]),
      ),
    );
  }
}

// ───────────────────────── multiple choice ─────────────────────────
class MultipleChoiceQuestion extends StatefulWidget {
  final Question q;
  final AnswerCallback onAnswer;
  const MultipleChoiceQuestion({super.key, required this.q, required this.onAnswer});
  @override
  State<MultipleChoiceQuestion> createState() => _MultipleChoiceQuestionState();
}

class _MultipleChoiceQuestionState extends State<MultipleChoiceQuestion> {
  late final List<String> opts;
  String? selected;

  @override
  void initState() {
    super.initState();
    opts = List<String>.of(widget.q.options)..shuffle(Random());
  }

  void _pick(String o) {
    Sfx.play('tap');
    setState(() => selected = o);
    widget.onAnswer(true, o == widget.q.correctAnswer);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < opts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PressScale(
              scale: 0.98,
              onTap: () => _pick(opts[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: selected == opts[i]
                    ? duoCard(border: AppColors.primary, fill: AppColors.tint, shadow: AppColors.primaryShadow)
                    : duoCard(),
                child: Row(children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected == opts[i] ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selected == opts[i] ? AppColors.primary : AppColors.locked, width: 2),
                    ),
                    child: Text(String.fromCharCode(65 + i),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected == opts[i] ? Colors.white : Colors.black45)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(opts[i],
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.3)),
                  ),
                ]),
              ),
            ),
          ),
      ]);
}

// ───────────────────────── categorize (sort into groups) ─────────────────────────
// JSON: "pairs": [{"left": "<term>", "right": "<group name>"}, ...]
class CategorizeQuestion extends StatefulWidget {
  final Question q;
  final AnswerCallback onAnswer;
  const CategorizeQuestion({super.key, required this.q, required this.onAnswer});
  @override
  State<CategorizeQuestion> createState() => _CategorizeQuestionState();
}

class _CategorizeQuestionState extends State<CategorizeQuestion> {
  static const _palette = [AppColors.primary, AppColors.streak, AppColors.success, Color(0xFF9B6BFF)];
  final List<String> groups = [];
  late final List<int> bank;
  final Map<int, int> placed = {}; // term index -> group index
  int? selected;

  @override
  void initState() {
    super.initState();
    for (final p in widget.q.pairs) {
      if (!groups.contains(p.right)) groups.add(p.right);
    }
    bank = List.generate(widget.q.pairs.length, (i) => i)..shuffle(Random());
  }

  int _groupOf(int t) => groups.indexOf(widget.q.pairs[t].right);

  void _report() {
    final ready = placed.length == widget.q.pairs.length;
    widget.onAnswer(ready, ready && placed.entries.every((e) => e.value == _groupOf(e.key)));
  }

  void _place(int t, int g) {
    Sfx.play('tap');
    setState(() {
      placed[t] = g;
      selected = null;
    });
    _report();
  }

  void _unplace(int t) {
    Sfx.play('tap');
    setState(() => placed.remove(t));
    _report();
  }

  Widget _selectedChip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: duoCard(border: AppColors.primary, fill: AppColors.tint, shadow: AppColors.primaryShadow),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink)),
      );

  Widget _bucket(int g) {
    final color = _palette[g % _palette.length];
    final items = placed.entries.where((e) => e.value == g).map((e) => e.key).toList();
    return DragTarget<int>(
      onAcceptWithDetails: (d) => _place(d.data, g),
      builder: (_, cand, __) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selected == null ? null : () => _place(selected!, g),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(minHeight: 88),
          decoration: duoCard(
              border: color, fill: (cand.isNotEmpty || selected != null) ? color.withOpacity(0.12) : Colors.white),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(groups[g], style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 15)),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text(selected == null ? 'Drag items here' : 'Tap to place here',
                  style: const TextStyle(color: Colors.black38, fontWeight: FontWeight.w700))
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in items) PressScale(onTap: () => _unplace(t), child: duoChip(widget.q.pairs[t].left)),
              ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var g = 0; g < groups.length; g++) _bucket(g),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final t in bank)
            if (!placed.containsKey(t))
              Draggable<int>(
                data: t,
                feedback: Material(
                    color: Colors.transparent,
                    child: Transform.scale(scale: 1.08, child: duoChip(widget.q.pairs[t].left))),
                childWhenDragging: duoChip(widget.q.pairs[t].left, ghost: true),
                child: PressScale(
                  onTap: () {
                    Sfx.play('tap');
                    setState(() => selected = selected == t ? null : t);
                  },
                  child: selected == t ? _selectedChip(widget.q.pairs[t].left) : duoChip(widget.q.pairs[t].left),
                ),
              ),
        ]),
      ]);
}
