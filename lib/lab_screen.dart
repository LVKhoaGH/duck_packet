import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cli_engine.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

// NOTE: this file uses the plain Flutter Text on purpose (terminal output must never be translated).

const Color _kGreen = Color(0xFF4DFF9A);
const Color _kRed = Color(0xFFFF8A8A);
const Color _kYellow = Color(0xFFFFD66B);

/// The lab as it appears inside a game session: brief + "Open terminal" button.
/// The simulator state lives here, so it survives opening/closing the terminal.
class LabQuestion extends StatefulWidget {
  final Question q;
  final void Function(bool ready, bool correct) onAnswer;
  const LabQuestion({super.key, required this.q, required this.onAnswer});
  @override
  State<LabQuestion> createState() => _LabQuestionState();
}

class _LabQuestionState extends State<LabQuestion> {
  late final LabSession s = LabSession(widget.q.lab);

  void _report() => widget.onAnswer(s.touched, s.passed());

  Future<void> _open() async {
    await Navigator.push(context, slideUpRoute(LabTerminalScreen(session: s, onChanged: _report)));
    if (!mounted) return;
    setState(() {});
    _report();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LabBrief(session: s),
      const SizedBox(height: 18),
      Button3D(label: s.touched ? 'Back to terminal' : 'Open terminal', onPressed: _open),
      if (s.touched)
        Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text('Done? Press Check Answer below.',
              style: TextStyle(color: AppColors.sub, fontWeight: FontWeight.w700)),
        ),
    ]);
  }
}

/// Scenario + topology + tasks.
class LabBrief extends StatelessWidget {
  final LabSession session;
  const LabBrief({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final topo = s.topologyLines();
    final tasks = s.tasks;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (s.scenario.isNotEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: duoCard(border: AppColors.line),
          child: Text(s.scenario,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.35)),
        ),
      if (topo.isNotEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: AppColors.terminalBg, borderRadius: BorderRadius.circular(14)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(topo.join('\n'), style: codeStyle.copyWith(fontSize: 12, color: _kGreen, height: 1.4)),
          ),
        ),
      for (var i = 0; i < tasks.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(tasks[i]['text'] ?? '',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.35)),
            ),
          ]),
        ),
    ]);
  }
}

/// Full-screen terminal. Type commands like on a real router (Tab completes, ? helps, up/down = history).
class LabTerminalScreen extends StatefulWidget {
  final LabSession session;
  final VoidCallback onChanged;
  const LabTerminalScreen({super.key, required this.session, required this.onChanged});
  @override
  State<LabTerminalScreen> createState() => _LabTerminalScreenState();
}

class _LabTerminalScreenState extends State<LabTerminalScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();
  int _hist = -1;

  LabSession get s => widget.session;
  TextStyle get _mono => codeStyle.copyWith(fontSize: 12, color: _kGreen, height: 1.35);

  @override
  void initState() {
    super.initState();
    _toEnd();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _setText(String t) {
    _ctrl.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }

  void _refocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _submit(String t) {
    setState(() {
      s.run(t);
      _hist = -1;
    });
    _ctrl.clear();
    widget.onChanged();
    _toEnd();
    _refocus();
  }

  void _changed(String v) {
    if (v.endsWith('?') && s.allowHelp) {
      final base = v.substring(0, v.length - 1);
      setState(() => s.runHelp(base));
      _setText(base);
      _toEnd();
    }
  }

  void _tab() {
    final c = s.complete(_ctrl.text);
    if (c != null) _setText(c);
    _refocus();
  }

  void _up() {
    final h = s.dev.history;
    if (h.isEmpty) return;
    _hist = _hist < 0 ? h.length - 1 : (_hist > 0 ? _hist - 1 : 0);
    _setText(h[_hist]);
  }

  void _down() {
    final h = s.dev.history;
    if (_hist < 0) return;
    if (_hist >= h.length - 1) {
      _hist = -1;
      _setText('');
    } else {
      _hist++;
      _setText(h[_hist]);
    }
  }

  void _helpKey() {
    if (!s.allowHelp) return;
    setState(() => s.runHelp(_ctrl.text));
    _toEnd();
    _refocus();
  }

  void _hint() {
    final h = s.nextHint();
    setState(() {
      s.dev.log.add(h == null ? '[no more hints]' : '[hint ${s.hintsUsed}/${s.maxHints}] $h');
    });
    _toEnd();
  }

  void _brief() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(child: LabBrief(session: s)),
        ),
      ),
    );
  }

  Color _lineColor(String l) {
    if (l.startsWith('%') || l.startsWith('Translating')) return _kRed;
    if (l.startsWith('[hint') || l.startsWith('[no more')) return _kYellow;
    return _kGreen;
  }

  Widget _key(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
            child: Text(label, style: _mono.copyWith(color: Colors.white)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final log = s.dev.log;
    return Scaffold(
      backgroundColor: AppColors.terminalBg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (var i = 0; i < s.devs.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              s.switchTo(i);
                              _hist = -1;
                            });
                            _ctrl.clear();
                            _toEnd();
                            _refocus();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: s.cur == i ? AppColors.primary : Colors.white12,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(s.devs[i].id,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.assignment_outlined, color: Colors.white),
                tooltip: 'Tasks',
                onPressed: _brief,
              ),
              if (s.maxHints > 0)
                IconButton(
                  icon: const Icon(Icons.lightbulb_outline_rounded, color: _kYellow),
                  tooltip: 'Hint',
                  onPressed: _hint,
                ),
            ]),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              var maxLen = 0;
              for (final l in log) {
                maxLen = max(maxLen, l.length);
              }
              final w = max(box.maxWidth, maxLen * 7.4 + 24);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: w,
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: log.length,
                    itemBuilder: (_, i) => Text(log[i], softWrap: false, style: _mono.copyWith(color: _lineColor(log[i]))),
                  ),
                ),
              );
            }),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _key('Tab', _tab),
                if (s.allowHelp) _key('?', _helpKey),
                _key('|', () => _setText('${_ctrl.text} | ')),
                _key('↑', _up),
                _key('↓', _down),
                _key('end', () => _submit('end')),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(children: [
              Text(s.promptText, style: _mono.copyWith(color: Colors.white)),
              const SizedBox(width: 6),
              Expanded(
                child: Focus(
                  onKeyEvent: (node, ev) {
                    if (ev is KeyDownEvent) {
                      if (ev.logicalKey == LogicalKeyboardKey.tab) {
                        _tab();
                        return KeyEventResult.handled;
                      }
                      if (ev.logicalKey == LogicalKeyboardKey.arrowUp) {
                        _up();
                        return KeyEventResult.handled;
                      }
                      if (ev.logicalKey == LogicalKeyboardKey.arrowDown) {
                        _down();
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLines: 1,
                    style: _mono.copyWith(color: Colors.white),
                    cursorColor: _kGreen,
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                    onChanged: _changed,
                    onSubmitted: _submit,
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
