import 'dart:math';
import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'models.dart';
import 'sfx.dart';
import 'theme.dart';
import 'widgets.dart';

/// "Choose two / three": tap options (max = number of correct answers). Ready only when exactly N are picked.
/// JSON: {"type":"multi_select","prompt":"...","options":[...],"correct_answers":["A","B"],"explanation":"..."}
class MultiSelectQuestion extends StatefulWidget {
  final Question q;
  final void Function(bool ready, bool correct) onAnswer;
  const MultiSelectQuestion({super.key, required this.q, required this.onAnswer});
  @override
  State<MultiSelectQuestion> createState() => _MultiSelectQuestionState();
}

class _MultiSelectQuestionState extends State<MultiSelectQuestion> {
  late final List<String> opts;
  final Set<String> sel = {};

  int get need => widget.q.correctAnswers.length;

  @override
  void initState() {
    super.initState();
    opts = List<String>.of(widget.q.options)..shuffle(Random());
  }

  void _toggle(String o) {
    Sfx.play('tap');
    setState(() {
      if (sel.contains(o)) {
        sel.remove(o);
      } else if (sel.length < need) {
        sel.add(o);
      }
    });
    final ready = sel.length == need;
    final ok = ready && widget.q.correctAnswers.every((a) => sel.contains(a));
    widget.onAnswer(ready, ok);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: AppColors.tint, borderRadius: BorderRadius.circular(20)),
        child: Text('Choose $need', style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < opts.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PressScale(
            scale: 0.98,
            onTap: () => _toggle(opts[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: sel.contains(opts[i])
                  ? duoCard(border: AppColors.primary, fill: AppColors.tint, shadow: AppColors.primaryShadow)
                  : duoCard(),
              child: Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel.contains(opts[i]) ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel.contains(opts[i]) ? AppColors.primary : AppColors.locked, width: 2),
                  ),
                  child: sel.contains(opts[i])
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                      : Text(String.fromCharCode(65 + i),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black45)),
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
}
