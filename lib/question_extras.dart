// question_extras.dart  (FILE MỚI)
// 3 dạng bài mới: show_output, route_predict, topology_drag + bộ vẽ sơ đồ mạng (TopologyCanvas).
// File này dùng Text gốc của Flutter (output terminal không được dịch); chuỗi tĩnh đi qua tr().
import 'package:flutter/material.dart';

import 'game_session_screen.dart' show MultipleChoiceQuestion, AnswerCallback;
import 'i18n.dart' show tr;
import 'models.dart';
import 'sfx.dart';
import 'theme.dart';

const TextStyle _mono = TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13, height: 1.45, color: Color(0xFF4DFF9A));

Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List _list(dynamic v) => v is List ? v : const [];
double _num(dynamic v, double d) => v is num ? v.toDouble() : (double.tryParse('$v') ?? d);

/// Đáp án đúng ở dạng chữ (hiện trong bảng "Correct solution" và màn kết quả thi thử).
String extraAnswerText(Question q) {
  if (q.type == 'topology_drag') {
    final topo = _map(q.raw['topology']);
    final slots = _list(topo['slots']);
    final ans = _map(q.raw['answers']);
    final lines = <String>[];
    for (var i = 0; i < slots.length; i++) {
      final id = '${_map(slots[i])['id']}';
      lines.add('${i + 1}: ${ans[id] ?? ''}');
    }
    return lines.join('\n');
  }
  return q.correctAnswer;
}

// ───────────────────────── sơ đồ mạng ─────────────────────────

IconData _kindIcon(String k) {
  switch (k) {
    case 'switch':
    case 'switch_l2':
    case 'switch_l3':
      return Icons.device_hub_rounded;
    case 'firewall':
      return Icons.security_rounded;
    case 'cloud':
    case 'internet':
      return Icons.cloud_rounded;
    case 'pc':
    case 'host':
      return Icons.computer_rounded;
    case 'server':
      return Icons.dns_rounded;
    case 'ap':
      return Icons.wifi_rounded;
    default:
      return Icons.router_rounded;
  }
}

/// Vẽ topology từ JSON: nodes[{id,label,kind,x,y}], links[{a,b,label,down}], slots[{id,x,y}] (x,y là % 0..100).
class TopologyCanvas extends StatelessWidget {
  final Map<String, dynamic> topo;
  final Widget Function(String slotId, int number)? slotBuilder;
  const TopologyCanvas({super.key, required this.topo, this.slotBuilder});

  @override
  Widget build(BuildContext context) {
    final nodes = _list(topo['nodes']).map(_map).toList();
    final links = _list(topo['links']).map(_map).toList();
    final slots = _list(topo['slots']).map(_map).toList();
    final ratio = _num(topo['ratio'], 0.62).clamp(0.35, 1.2);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final h = w * ratio;
      Offset at(dynamic x, dynamic y) => Offset(_num(x, 50) / 100 * w, _num(y, 50) / 100 * h);
      final pos = <String, Offset>{for (final n in nodes) '${n['id']}': at(n['x'], n['y'])};
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFFF7FBFD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line, width: 2),
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: CustomPaint(painter: _LinkPainter(links, pos))),
          for (final n in nodes)
            Positioned(
              left: pos['${n['id']}']!.dx - 36,
              top: pos['${n['id']}']!.dy - 26,
              width: 72,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: n['kind'] == 'cloud' ? AppColors.secondary : AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: AppColors.primaryShadow, offset: Offset(0, 3))],
                  ),
                  child: Icon(_kindIcon('${n['kind'] ?? 'router'}'), color: Colors.white, size: 26),
                ),
                const SizedBox(height: 4),
                Text('${n['label'] ?? n['id']}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ]),
            ),
          if (slotBuilder != null)
            for (var i = 0; i < slots.length; i++)
              Positioned(
                left: at(slots[i]['x'], slots[i]['y']).dx - 46,
                top: at(slots[i]['x'], slots[i]['y']).dy - 20,
                width: 92,
                height: 40,
                child: slotBuilder!('${slots[i]['id']}', i + 1),
              ),
        ]),
      );
    });
  }
}

class _LinkPainter extends CustomPainter {
  final List<Map<String, dynamic>> links;
  final Map<String, Offset> pos;
  _LinkPainter(this.links, this.pos);

  @override
  void paint(Canvas canvas, Size size) {
    for (final l in links) {
      final a = pos['${l['a']}'], b = pos['${l['b']}'];
      if (a == null || b == null) continue;
      final down = l['down'] == true;
      final p = Paint()
        ..color = down ? AppColors.error : AppColors.locked
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      if (down) {
        final d = (b - a);
        final len = d.distance;
        final dir = d / len;
        for (double s = 0; s < len; s += 14) {
          canvas.drawLine(a + dir * s, a + dir * (s + 7 > len ? len : s + 7), p);
        }
      } else {
        canvas.drawLine(a, b, p);
      }
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      if (down) {
        final x = Paint()
          ..color = AppColors.error
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(mid + const Offset(-8, -8), mid + const Offset(8, 8), x);
        canvas.drawLine(mid + const Offset(-8, 8), mid + const Offset(8, -8), x);
      }
      final label = '${l['label'] ?? ''}';
      if (label.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
              text: label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: down ? AppColors.error : AppColors.primaryShadow)),
          textDirection: TextDirection.ltr,
        )..layout();
        final off = down ? const Offset(0, -22) : Offset.zero;
        final r = RRect.fromRectAndRadius(
            Rect.fromCenter(center: mid + off, width: tp.width + 12, height: tp.height + 6), const Radius.circular(8));
        canvas.drawRRect(r, Paint()..color = Colors.white);
        canvas.drawRRect(r, Paint()
          ..color = AppColors.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
        tp.paint(canvas, mid + off - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinkPainter old) => true;
}

// ───────────────────────── show_output ─────────────────────────

class ShowOutputQuestion extends StatelessWidget {
  final Question q;
  final AnswerCallback onAnswer;
  const ShowOutputQuestion({super.key, required this.q, required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    final out = '${q.raw['output'] ?? ''}'.replaceAll('\r\n', '\n');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.terminalBg, borderRadius: BorderRadius.circular(14)),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SelectableText(out, style: _mono)),
      ),
      const SizedBox(height: 18),
      MultipleChoiceQuestion(q: q, onAnswer: onAnswer),
    ]);
  }
}

// ───────────────────────── route_predict ─────────────────────────

class RoutePredictQuestion extends StatefulWidget {
  final Question q;
  final AnswerCallback onAnswer;
  const RoutePredictQuestion({super.key, required this.q, required this.onAnswer});
  @override
  State<RoutePredictQuestion> createState() => _RoutePredictQuestionState();
}

class _RoutePredictQuestionState extends State<RoutePredictQuestion> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  bool _same(String a, String b) {
    final x = a.trim().toLowerCase(), y = b.trim().toLowerCase();
    if (x == y) return true;
    final nx = double.tryParse(x), ny = double.tryParse(y);
    return nx != null && ny != null && nx == ny;
  }

  void _changed(String v) {
    final accepted = <String>[widget.q.correctAnswer, ..._list(widget.q.raw['accept']).map((e) => '$e')];
    widget.onAnswer(v.trim().isNotEmpty, accepted.any((a) => _same(a, v)));
  }

  @override
  Widget build(BuildContext context) {
    final topo = _map(widget.q.raw['topology']);
    final unit = '${widget.q.raw['unit'] ?? ''}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TopologyCanvas(topo: topo),
      const SizedBox(height: 18),
      if (widget.q.options.isNotEmpty)
        MultipleChoiceQuestion(q: widget.q, onAnswer: widget.onAnswer)
      else
        TextField(
          controller: _ctl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autocorrect: false,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink),
          onChanged: _changed,
          decoration: InputDecoration(
            labelText: tr('Your answer'),
            suffixText: unit.isEmpty ? null : unit,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
    ]);
  }
}

// ───────────────────────── topology_drag ─────────────────────────

class TopologyDragQuestion extends StatefulWidget {
  final Question q;
  final AnswerCallback onAnswer;
  const TopologyDragQuestion({super.key, required this.q, required this.onAnswer});
  @override
  State<TopologyDragQuestion> createState() => _TopologyDragQuestionState();
}

class _TopologyDragQuestionState extends State<TopologyDragQuestion> {
  late final List<String> _labels = _list(widget.q.raw['labels']).map((e) => '$e').toList()..shuffle();
  late final Map<String, dynamic> _answers = _map(widget.q.raw['answers']);
  late final List<String> _slotIds = _list(_map(widget.q.raw['topology'])['slots']).map((s) => '${_map(s)['id']}').toList();
  final Map<String, int> _placed = {}; // slotId -> chỉ số trong _labels
  int? _sel; // nhãn đang chọn (chạm để đặt)

  void _report() {
    final ready = _placed.length == _slotIds.length;
    var ok = ready;
    if (ready) {
      for (final s in _slotIds) {
        if (_labels[_placed[s]!] != '${_answers[s]}') ok = false;
      }
    }
    widget.onAnswer(ready, ok);
  }

  void _place(String slot, int idx) {
    Sfx.play('tap');
    setState(() {
      _placed.removeWhere((k, v) => v == idx); // một nhãn chỉ ở một ô
      _placed[slot] = idx;
      _sel = null;
    });
    _report();
  }

  void _clear(String slot) {
    Sfx.play('tap');
    setState(() => _placed.remove(slot));
    _report();
  }

  Widget _chip(String t, {bool sel = false, bool ghost = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: ghost ? const Color(0xFFF1F3F5) : (sel ? AppColors.tint : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? AppColors.primary : (ghost ? AppColors.line : AppColors.locked), width: 2),
        ),
        child: Text(t,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ghost ? Colors.black26 : AppColors.ink)),
      );

  @override
  Widget build(BuildContext context) {
    final topo = _map(widget.q.raw['topology']);
    final used = _placed.values.toSet();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TopologyCanvas(
        topo: topo,
        slotBuilder: (id, n) => DragTarget<int>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (d) => _place(id, d.data),
          builder: (ctx, cand, rej) {
            final has = _placed.containsKey(id);
            final hot = cand.isNotEmpty;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (has) {
                  _clear(id);
                } else if (_sel != null) {
                  _place(id, _sel!);
                }
              },
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: has ? Colors.white : (hot ? AppColors.tint : const Color(0xFFEAF6FB)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: hot || (_sel != null && !has) ? AppColors.primary : AppColors.secondary, width: 2),
                ),
                child: Text(has ? _labels[_placed[id]!] : '$n',
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: has ? 12 : 16, fontWeight: FontWeight.w700, color: has ? AppColors.ink : AppColors.secondary)),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 10),
      Text(tr('Drag a label into a numbered box, or tap a label then tap a box. Tap a filled box to remove it.'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black38)),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (var i = 0; i < _labels.length; i++)
          used.contains(i)
              ? _chip(_labels[i], ghost: true)
              : Draggable<int>(
                  data: i,
                  feedback: Material(color: Colors.transparent, child: _chip(_labels[i], sel: true)),
                  childWhenDragging: _chip(_labels[i], ghost: true),
                  child: GestureDetector(
                    onTap: () {
                      Sfx.play('tap');
                      setState(() => _sel = _sel == i ? null : i);
                    },
                    child: _chip(_labels[i], sel: _sel == i),
                  ),
                ),
      ]),
    ]);
  }
}
