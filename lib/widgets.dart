import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'duck.dart';
import 'providers.dart';
import 'sfx.dart';
import 'theme.dart';

/// Gentle floating up/down loop.
class Bobbing extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration period;
  const Bobbing({super.key, required this.child, this.amplitude = 6, this.period = const Duration(milliseconds: 1600)});
  @override
  State<Bobbing> createState() => _BobbingState();
}

class _BobbingState extends State<Bobbing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period)..repeat(reverse: true);
  late final Animation<double> _curve = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _curve,
        builder: (_, child) => Transform.translate(offset: Offset(0, -widget.amplitude * _curve.value), child: child),
        child: widget.child,
      );
}

/// Expanding fading ring behind [child] (used for the current node).
class PulseRing extends StatefulWidget {
  final Widget child;
  final Color color;
  final double size;
  const PulseRing({super.key, required this.child, required this.color, required this.size});
  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) {
            final t = _c.value;
            final d = widget.size * 0.28 * t;
            return Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: -d,
                top: -d,
                right: -d,
                bottom: -d,
                child: DecoratedBox(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: 0.35 * (1 - t)))),
              ),
              Positioned.fill(child: child!),
            ]);
          },
          child: widget.child,
        ),
      );
}

/// One-shot confetti burst. Place inside a Stack with Positioned.fill.
class _P {
  final double x, delay, speed, size, rot, drift;
  final Color color;
  _P(this.x, this.delay, this.speed, this.size, this.rot, this.drift, this.color);
}

class Confetti extends StatefulWidget {
  const Confetti({super.key});
  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))..forward();
  late final List<_P> _ps = () {
    final r = Random();
    const colors = [AppColors.primary, AppColors.success, AppColors.streak, AppColors.error, Colors.white, AppColors.secondary];
    return List.generate(
        70,
        (_) => _P(r.nextDouble(), r.nextDouble() * 0.35, 0.7 + r.nextDouble() * 0.5, 7 + r.nextDouble() * 6,
            r.nextDouble() * 6, 10 + r.nextDouble() * 30, colors[r.nextInt(colors.length)]));
  }();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_ps, _c.value)),
        ),
      );
}

class _ConfettiPainter extends CustomPainter {
  final List<_P> ps;
  final double t;
  _ConfettiPainter(this.ps, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    for (final p in ps) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * (size.height + 40) * p.speed;
      final x = p.x * size.width + sin(local * 8 + p.rot) * p.drift;
      final paint = Paint()..color = p.color.withValues(alpha: (1 - local * local).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * 10 + p.rot);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// Number that pops when its value changes.
class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle style;
  const AnimatedCount(this.value, {super.key, this.style = const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)});
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: Text('$value', key: ValueKey(value), style: style),
      );
}

/// Rounded stat chip for the AppBar.
class StatPill extends StatelessWidget {
  final String icon;
  final int value;
  const StatPill(this.icon, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SvgIcon(icon, size: 20),
          const SizedBox(width: 4),
          AnimatedCount(value),
        ]),
      );
}

/// Duck that gives a random networking tip when tapped.
class MascotTip extends StatefulWidget {
  final bool bubbleRight;
  const MascotTip({super.key, this.bubbleRight = false});
  @override
  State<MascotTip> createState() => _MascotTipState();
}

class _MascotTipState extends State<MascotTip> {
  static const _tips = [
    'OSPF có AD 110, còn eBGP có AD 20.',
    'Dead interval của OSPF mặc định gấp 4 lần Hello.',
    'Root bridge là switch có Bridge ID thấp nhất.',
    'SD-WAN Controller hoạt động như route reflector cho OMP.',
    'VXLAN thêm 50 byte, nên underlay SD-Access đặt MTU 9100.',
    'NETCONF chạy trên SSH, cổng TCP 830.',
  ];
  final _r = Random();
  String? _tip;
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _tap() {
    Sfx.play('tap');
    setState(() => _tip = _tips[_r.nextInt(_tips.length)]);
    _t?.cancel();
    _t = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _tip = null);
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 84,
        height: 84,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: Center(child: DuckView(size: 72, onTap: _tap)),
          ),
          Positioned(
            bottom: 92,
            left: widget.bubbleRight ? null : 0,
            right: widget.bubbleRight ? 0 : null,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (c, a) => ScaleTransition(
                  scale: a, alignment: widget.bubbleRight ? Alignment.bottomRight : Alignment.bottomLeft, child: c),
              child: _tip == null
                  ? const SizedBox.shrink(key: ValueKey('none'))
                  : Container(
                      key: ValueKey(_tip),
                      constraints: const BoxConstraints(maxWidth: 220),
                      padding: const EdgeInsets.all(10),
                      decoration: duoCard(border: AppColors.primary, shadow: AppColors.primaryShadow, radius: 14),
                      child: Text(_tip!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
                    ),
            ),
          ),
        ]),
      );
}

/// Horizontal shake whenever [trigger] changes (0 = never shaken).
class Shake extends StatefulWidget {
  final int trigger;
  final Widget child;
  const Shake({super.key, required this.trigger, required this.child});
  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(offset: Offset(sin(_c.value * pi * 6) * 10 * (1 - _c.value), 0), child: child),
        child: widget.child,
      );
}

/// Green animated progress bar with a highlight strip.
class ProgressBar3D extends StatelessWidget {
  final double value;
  final Color track, fill;
  const ProgressBar3D(this.value, {super.key, this.track = Colors.white30, this.fill = AppColors.success});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(end: value),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Container(
          height: 16,
          decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(8)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v.clamp(0.04, 1.0),
              child: Container(
                decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.fromLTRB(6, 3, 6, 0),
                alignment: Alignment.topCenter,
                child: Container(height: 4, decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(2))),
              ),
            ),
          ),
        ),
      );
}

Route<T> slideUpRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => _Narrow(page),
      transitionsBuilder: (_, a, __, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(c),
          child: FadeTransition(opacity: c, child: child),
        );
      },
    );

/// Pushed screens keep a phone-like width (max 720 px) on laptops; the sides get the page background colour.
class _Narrow extends StatelessWidget {
  final Widget child;
  const _Narrow(this.child);
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => c.maxWidth <= 720
            ? child
            : ColoredBox(
                color: const Color(0xFFE9EDF1),
                child: Align(alignment: Alignment.topCenter, child: SizedBox(width: 720, child: child)),
              ),
      );
}

/// Word-bank style chip.
Widget duoChip(String t, {bool mono = false, bool ghost = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: ghost ? BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(16)) : duoCard(),
      child: Text(t,
          style: TextStyle(
              fontFamily: mono ? 'JetBrainsMono' : null,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: ghost ? Colors.transparent : AppColors.ink)),
    );

/// Mon–Sun row with the days you practiced.
class WeekRow extends StatelessWidget {
  final Set<String> days;
  const WeekRow(this.days, {super.key});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayKey = dayKey(now);
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      for (var i = 0; i < 7; i++)
        Builder(builder: (_) {
          final d = DateTime(now.year, now.month, now.day - (now.weekday - 1) + i);
          final k = dayKey(d);
          final done = days.contains(k);
          final today = k == todayKey;
          return Column(children: [
            Text(labels[i], style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black45)),
            const SizedBox(height: 6),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.streak : AppColors.line,
                border: today && !done ? Border.all(color: AppColors.streak, width: 3) : null,
              ),
              child: done ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
            ),
          ]);
        }),
    ]);
  }
}

/// Returns true when the user chooses to end the session.
Future<bool?> showQuitSheet(BuildContext context) => showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const DuckView(size: 100, mood: DuckMood.confused),
            const SizedBox(height: 12),
            const Text("Wait, don't go!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 6),
            const Text("You'll lose your progress on this lesson.", style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 20),
            Button3D(label: 'Keep learning', onPressed: () => Navigator.pop(ctx, false)),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('END SESSION', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ),
          ]),
        ),
      ),
    );


/// Scale-in entrance (overshoots slightly). Larger [delay] = slower pop.
class Pop extends StatelessWidget {
  final int delay;
  final Widget child;
  const Pop({super.key, this.delay = 0, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 380 + delay),
        curve: Curves.easeOutBack,
        builder: (_, v, c) => Transform.scale(scale: v, child: c),
        child: child,
      );
}

/// Tappable wrapper that shrinks a little while pressed.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const PressScale({super.key, required this.child, this.onTap, this.scale = 0.95});
  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}
