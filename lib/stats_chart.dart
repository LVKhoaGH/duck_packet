import 'dart:math';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'history.dart';
import 'i18n.dart';
import 'sfx.dart';
import 'study.dart' show dayNum;
import 'theme.dart';
import 'widgets.dart';

enum ChartRange { week, month, quarter, half, year, total }

const _labels = {
  ChartRange.week: '1W',
  ChartRange.month: '1M',
  ChartRange.quarter: '3M',
  ChartRange.half: '6M',
  ChartRange.year: '1Y',
  ChartRange.total: 'All',
};

class _Bucket {
  int xp = 0, ans = 0, ok = 0;
}

class _Cfg {
  final int span, bucket; // days shown, days per bar
  _Cfg(this.span, this.bucket);
}

_Cfg _cfg(ChartRange r, Map<int, List<int>> h, int today) {
  switch (r) {
    case ChartRange.week:
      return _Cfg(7, 1);
    case ChartRange.month:
      return _Cfg(30, 1);
    case ChartRange.quarter:
      return _Cfg(91, 7);
    case ChartRange.half:
      return _Cfg(182, 7);
    case ChartRange.year:
      return _Cfg(365, 30);
    case ChartRange.total:
      final first = h.keys.isEmpty ? today : h.keys.reduce(min);
      final span = max(7, today - first + 1);
      return _Cfg(span, (span / 20).ceil());
  }
}

String _date(int day, bool longRange) {
  final d = DateTime.fromMillisecondsSinceEpoch(day * 86400000, isUtc: true);
  return longRange ? '${d.month}/${d.year % 100}' : '${d.day}/${d.month}';
}

/// XP per day/week/month as bars, accuracy as a line. Range is chosen with the chips.
class ProgressChartCard extends ConsumerStatefulWidget {
  const ProgressChartCard({super.key});
  @override
  ConsumerState<ProgressChartCard> createState() => _ProgressChartCardState();
}

class _ProgressChartCardState extends ConsumerState<ProgressChartCard> {
  ChartRange _r = ChartRange.week;

  @override
  Widget build(BuildContext context) {
    final h = ref.watch(historyProvider).days;
    final today = dayNum();
    final cfg = _cfg(_r, h, today);
    final nb = (cfg.span / cfg.bucket).ceil();
    final start = today - nb * cfg.bucket + 1;

    final buckets = List.generate(nb, (_) => _Bucket());
    var xp = 0, ans = 0, ok = 0, active = 0;
    h.forEach((d, row) {
      if (d < start || d > today) return;
      final b = buckets[(d - start) ~/ cfg.bucket];
      b.xp += row[0];
      b.ans += row[1];
      b.ok += row[2];
      xp += row[0];
      ans += row[1];
      ok += row[2];
      if (row[0] > 0 || row[1] > 0) active++;
    });
    final maxXp = max(10, buckets.fold<int>(0, (a, b) => max(a, b.xp)));
    final acc = ans == 0 ? 0 : (ok * 100 / ans).round();
    final longRange = cfg.span > 120;

    Widget stat(String v, String label, Color c) => Expanded(
          child: Column(children: [
            Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c)),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black38)),
          ]),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: duoCard(border: AppColors.line),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.show_chart_rounded, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          for (final r in ChartRange.values)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: r == ChartRange.total ? 0 : 4),
                child: PressScale(
                  onTap: () {
                    Sfx.play('tap');
                    setState(() => _r = r);
                  },
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: _r == r
                        ? duoCard(border: AppColors.primary, fill: AppColors.tint, shadow: AppColors.primaryShadow, radius: 10)
                        : duoCard(radius: 10),
                    child: Text(_labels[r]!,
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: _r == r ? AppColors.primaryShadow : Colors.black45)),
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          stat('$xp', 'XP', AppColors.primary),
          stat('$ans', 'Questions', AppColors.ink),
          stat(ans == 0 ? '-' : '$acc%', 'Accuracy', AppColors.success),
          stat('$active', 'Active days', AppColors.streak),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 150,
          width: double.infinity,
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _ChartPainter(buckets, maxXp))),
            Positioned(left: 2, top: 0, child: Text('$maxXp XP', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black26))),
          ]),
        ),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_date(start, longRange), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black38)),
          Text(_date(today, longRange), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black38)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          const Text('XP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(width: 14),
          Container(width: 14, height: 4, decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          const Text('Accuracy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45)),
        ]),
        if (h.isEmpty) ...[
          const SizedBox(height: 8),
          const Text('The chart fills up as you study. Earlier days are not recorded.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38)),
        ],
      ]),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<_Bucket> b;
  final int maxXp;
  _ChartPainter(this.b, this.maxXp);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1.5;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final n = b.length;
    final gap = n > 14 ? 2.0 : 6.0;
    final bw = (size.width - gap * (n - 1)) / n;
    final bar = Paint()..color = AppColors.primary;
    for (var i = 0; i < n; i++) {
      if (b[i].xp == 0) continue;
      final hgt = max(3.0, size.height * 0.92 * b[i].xp / maxXp);
      final x = i * (bw + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - hgt, bw, hgt), Radius.circular(min(4.0, bw / 2))),
        bar,
      );
    }
    final pts = <Offset>[];
    for (var i = 0; i < n; i++) {
      if (b[i].ans == 0) continue;
      final a = b[i].ok / b[i].ans;
      pts.add(Offset(i * (bw + gap) + bw / 2, size.height * 0.04 + size.height * 0.92 * (1 - a)));
    }
    if (pts.isEmpty) return;
    final line = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, line);
    final dot = Paint()..color = AppColors.success;
    final ring = Paint()..color = Colors.white;
    for (final p in pts) {
      canvas.drawCircle(p, 5, ring);
      canvas.drawCircle(p, 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}
