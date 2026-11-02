import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'game_session_screen.dart';
import 'models.dart';
import 'providers.dart';
import 'sfx.dart';
import 'study.dart';
import 'theme.dart';
import 'widgets.dart';

// ───────────────────────── Learn tab: list of lessons ─────────────────────────
class LearnTab extends ConsumerWidget {
  final Course? course;
  const LearnTab({super.key, required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = course;
    if (c == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Import a course to start learning.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 16)),
        ),
      );
    }
    final seen = ref.watch(studyProvider).seen;
    final withLesson = c.allNodes.where((n) => n.lesson.isNotEmpty).length;
    final read = c.allNodes.where((n) => n.lesson.isNotEmpty && seen.contains(n.id)).length;

    final children = <Widget>[
      Row(children: [
        Image.asset('assets/mascot/duck_happy.png', height: 64, errorBuilder: (_, __, ___) => const SizedBox(height: 64, width: 64)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Learn', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.ink)),
            Text('$read / $withLesson lessons read  ·  swipe the cards',
                style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
      const SizedBox(height: 8),
    ];

    for (final ch in c.chapters) {
      if (ch.nodes.isEmpty) continue;
      children.add(Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(ch.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.secondary)),
      ));
      for (final n in ch.nodes) {
        final has = n.lesson.isNotEmpty;
        final isSeen = seen.contains(n.id);
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PressScale(
            scale: 0.98,
            onTap: () {
              Sfx.play('tap');
              if (!has) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lesson coming soon')));
                return;
              }
              Navigator.push(context, slideUpRoute(LessonScreen(course: c, node: n)));
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: has ? duoCard(border: isSeen ? AppColors.success : AppColors.line) : duoCard(border: AppColors.line, fill: const Color(0xFFF7F7F7), shadow: AppColors.line),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: !has ? AppColors.line : (isSeen ? AppColors.success : AppColors.primary),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(!has ? Icons.hourglass_empty_rounded : (isSeen ? Icons.check_rounded : Icons.menu_book_rounded),
                      color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: has ? AppColors.ink : AppColors.lockedShadow)),
                    Text(has ? '${n.lesson.length} cards' : 'Coming soon',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.black38)),
                  ]),
                ),
                if (has) const Icon(Icons.chevron_right_rounded, color: AppColors.locked),
              ]),
            ),
          ),
        ));
      }
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: children);
  }
}

// ───────────────────────── Lesson: swipe left/right ─────────────────────────
class LessonScreen extends ConsumerStatefulWidget {
  final Course course;
  final CourseNode node;
  const LessonScreen({super.key, required this.course, required this.node});
  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  final _pc = PageController();
  int _page = 0;

  List<LessonCard> get _cards => widget.node.lesson;
  bool get _last => _page >= _cards.length - 1;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _go(int p) => _pc.animateToPage(p, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);

  void _next() {
    Sfx.play('tap');
    if (!_last) {
      _go(_page + 1);
      return;
    }
    ref.read(studyProvider.notifier).markSeen(widget.node.id);
    final canFight = widget.node.questions.isNotEmpty &&
        stageUnlocked(widget.course, ref.read(statsProvider).completed, widget.node.id);
    if (canFight) {
      Navigator.pushReplacement(context, slideUpRoute(GameSessionScreen(node: widget.node)));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _cards.length;
    final canFight = widget.node.questions.isNotEmpty &&
        stageUnlocked(widget.course, ref.watch(statsProvider).completed, widget.node.id);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 4),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.close_rounded, size: 30, color: Color(0xFFAFAFAF)), onPressed: () => Navigator.pop(context)),
              Expanded(child: ProgressBar3D((_page + 1) / n, track: AppColors.line)),
              const SizedBox(width: 12),
              Text('${_page + 1}/$n', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black45)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.node.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black45)),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: n,
              onPageChanged: (i) {
                setState(() => _page = i);
                if (i == n - 1) ref.read(studyProvider.notifier).markSeen(widget.node.id);
              },
              itemBuilder: (_, i) => _CardView(card: _cards[i]),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line, width: 2))),
            child: Row(children: [
              if (_page > 0) ...[
                SizedBox(
                  width: 110,
                  child: Button3D(
                    label: 'Back',
                    color: Colors.white,
                    shadow: AppColors.locked,
                    textColor: AppColors.ink,
                    onPressed: () {
                      Sfx.play('tap');
                      _go(_page - 1);
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Button3D(
                  label: !_last ? 'Next' : (canFight ? 'Go fight!' : 'Done'),
                  color: _last && canFight ? AppColors.error : AppColors.primary,
                  shadow: _last && canFight ? AppColors.errorShadow : AppColors.primaryShadow,
                  onPressed: _next,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Card rendering ─────────────────────────
const _purple = Color(0xFF9B6BFF);
const _flowPalette = [AppColors.primary, AppColors.streak, AppColors.success, _purple, AppColors.error, Color(0xFFFF7BAC)];

class _CardView extends StatelessWidget {
  final LessonCard card;
  const _CardView({required this.card});

  Color get _color {
    switch (card.type) {
      case 'flow':
        return AppColors.secondary;
      case 'code':
        return AppColors.terminalBg;
      case 'compare':
        return _purple;
      case 'tip':
        return AppColors.streak;
      case 'warn':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  String get _label {
    switch (card.type) {
      case 'flow':
        return 'HOW IT FLOWS';
      case 'code':
        return 'CLI';
      case 'compare':
        return 'COMPARE';
      case 'tip':
        return 'EXAM TIP';
      case 'warn':
        return 'WATCH OUT';
      default:
        return 'KEY IDEAS';
    }
  }

  Widget _para(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(t, style: const TextStyle(fontSize: 16, height: 1.45, color: AppColors.ink)),
      );

  Widget _bullet(String t, Color c) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 10),
            child: Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          ),
          Expanded(child: Text(t, style: const TextStyle(fontSize: 16, height: 1.4, color: AppColors.ink))),
        ]),
      );

  Widget _flow(List<MapEntry<String, String>> steps) {
    final colors = <String, Color>{};
    for (final s in steps) {
      if (s.key.isNotEmpty && !colors.containsKey(s.key)) colors[s.key] = _flowPalette[colors.length % _flowPalette.length];
    }
    return Column(children: [
      for (var i = 0; i < steps.length; i++) ...[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors[steps[i].key] ?? AppColors.secondary, shape: BoxShape.circle),
            child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (steps[i].key.isNotEmpty)
                Text(steps[i].key,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colors[steps[i].key] ?? AppColors.secondary)),
              Text(steps[i].value, style: const TextStyle(fontSize: 15, height: 1.35, color: AppColors.ink)),
            ]),
          ),
        ]),
        if (i < steps.length - 1)
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 2, bottom: 2),
            child: Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.locked),
          ),
      ],
    ]);
  }

  Widget _table(List<String> headers, List<List<String>> rows, Color color) {
    var cols = headers.length;
    for (final r in rows) {
      if (r.length > cols) cols = r.length;
    }
    if (cols == 0) return const SizedBox.shrink();
    List<String> pad(List<String> r) => [...r, for (var i = r.length; i < cols; i++) ''];
    Widget cell(String t, {bool bold = false}) => Padding(
          padding: const EdgeInsets.all(9),
          child: Text(t, style: TextStyle(fontSize: 14, height: 1.3, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: AppColors.ink)),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: AppColors.line, width: 2), borderRadius: BorderRadius.circular(14)),
        child: Table(
          border: TableBorder.symmetric(inside: const BorderSide(color: AppColors.line, width: 2)),
          defaultColumnWidth: const FlexColumnWidth(1.3),
          columnWidths: const {0: FlexColumnWidth(1.0)},
          children: [
            if (headers.isNotEmpty)
              TableRow(
                decoration: BoxDecoration(color: color.withOpacity(0.14)),
                children: [for (final h in pad(headers)) cell(h, bold: true)],
              ),
            for (final r in rows)
              TableRow(children: [
                for (var i = 0; i < cols; i++) cell(pad(r)[i], bold: i == 0),
              ]),
          ],
        ),
      ),
    );
  }

  List<Widget> _content() {
    final c = _color;
    final out = <Widget>[];
    final body = card.body;
    final isNote = card.type == 'tip' || card.type == 'warn';

    if (isNote) {
      if (body.isNotEmpty) {
        out.add(Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(card.type == 'tip' ? Icons.lightbulb_rounded : Icons.warning_amber_rounded, color: c),
            const SizedBox(width: 10),
            Expanded(child: Text(body, style: const TextStyle(fontSize: 16, height: 1.45, color: AppColors.ink))),
          ]),
        ));
      }
    } else if (body.isNotEmpty) {
      out.add(_para(body));
    }

    switch (card.type) {
      case 'flow':
        out.add(_flow(card.steps));
        break;
      case 'code':
        out.add(Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.terminalBg, borderRadius: BorderRadius.circular(14)),
          child: Text(card.code, style: codeStyle.copyWith(fontSize: 14)),
        ));
        break;
      case 'compare':
        out.add(_table(card.headers, card.rows, c));
        break;
      default:
        break;
    }
    for (final b in card.bullets) {
      out.add(_bullet(b, c));
    }
    if (card.note.isNotEmpty) {
      out.add(const SizedBox(height: 10));
      out.add(Text(card.note, style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black54, fontWeight: FontWeight.w700)));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Container(
        width: double.infinity,
        decoration: duoCard(border: c, radius: 20),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(20)),
              child: Text(_label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.8)),
            ),
            const SizedBox(height: 12),
            if (card.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(card.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.2)),
              ),
            ..._content(),
          ]),
        ),
      ),
    );
  }
}
