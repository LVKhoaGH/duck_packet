import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'sfx.dart';
import 'theme.dart';
import 'widgets.dart';

/// Shown after the first lesson of the day (Duolingo-style streak celebration).
class StreakScreen extends ConsumerStatefulWidget {
  final int streak;
  const StreakScreen({super.key, required this.streak});
  @override
  ConsumerState<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends ConsumerState<StreakScreen> {
  @override
  void initState() {
    super.initState();
    Sfx.play('streak');
  }

  @override
  Widget build(BuildContext context) {
    final days = ref.watch(statsProvider).days;
    final s = widget.streak;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutBack,
                builder: (_, v, c) => Transform.scale(scale: v, child: c),
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        AppColors.streak.withValues(alpha: 0.35),
                        AppColors.streak.withValues(alpha: 0.0),
                      ]),
                    ),
                  ),
                  const Bobbing(amplitude: 8, child: SvgIcon('ic_fire', size: 150)),
                ]),
              ),
              const SizedBox(height: 4),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: max(0, s - 1), end: s),
                duration: const Duration(milliseconds: 900),
                builder: (_, v, __) => Text('$v',
                    style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w700, color: AppColors.streak, height: 1)),
              ),
              const Pop(
                delay: 200,
                child: Text('day streak!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.streak)),
              ),
              const SizedBox(height: 28),
              Pop(
                delay: 300,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: duoCard(),
                  child: WeekRow(days),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Practice every day to keep your streak alive.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
              const Spacer(),
              Button3D(
                  label: 'Continue',
                  color: AppColors.streak,
                  shadow: AppColors.streakShadow,
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
        ),
        const Positioned.fill(child: Confetti()),
      ]),
    );
  }
}
