import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'i18n.dart';
import 'providers.dart';
import 'theme.dart';
import 'widgets.dart';

class TitleDef {
  final int xp;
  final String en, vi;
  final IconData icon;
  final Color color;
  const TitleDef(this.xp, this.en, this.vi, this.icon, this.color);
  String get name => AppLang.vi ? vi : en;
}

/// Placeholder names, change them freely. Keep the list sorted by xp (first one must be 0).
const kTitles = [
  TitleDef(0, 'Hatchling', 'Vịt Con', Icons.egg_alt_rounded, AppColors.lockedShadow),
  TitleDef(500, 'Ping Duck', 'Vịt Ping', Icons.wifi_tethering_rounded, AppColors.primary),
  TitleDef(1000, 'Packet Duck', 'Vịt Gói Tin', Icons.mail_rounded, AppColors.success),
  TitleDef(2500, 'Router Duck', 'Vịt Định Tuyến', Icons.router_rounded, AppColors.secondary),
  TitleDef(5000, 'Firewall Duck', 'Vịt Tường Lửa', Icons.security_rounded, AppColors.error),
  TitleDef(10000, 'Fabric Architect', 'Vịt Kiến Trúc Sư', Icons.account_tree_rounded, Color(0xFF9B6BFF)),
  TitleDef(20000, 'Legendary Duck', 'Vịt Huyền Thoại', Icons.workspace_premium_rounded, AppColors.streak),
];

int titleIndex(int xp) {
  var r = 0;
  for (var i = 0; i < kTitles.length; i++) {
    if (xp >= kTitles[i].xp) r = i;
  }
  return r;
}

TitleDef titleFor(int xp) => kTitles[titleIndex(xp)];

class TitlesScreen extends ConsumerWidget {
  const TitlesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xp = ref.watch(statsProvider).xp;
    final cur = titleIndex(xp);
    final next = cur + 1 < kTitles.length ? kTitles[cur + 1] : null;
    final t = kTitles[cur];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 4),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 28, color: Color(0xFFAFAFAF)), onPressed: () => Navigator.pop(context)),
              const Expanded(child: Text('Titles', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink))),
              Text('$xp XP', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black45)),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: duoCard(border: t.color, fill: t.color.withValues(alpha: 0.08)),
                child: Column(children: [
                  Icon(t.icon, size: 54, color: t.color),
                  const SizedBox(height: 6),
                  Text(t.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: t.color)),
                  const SizedBox(height: 10),
                  if (next != null) ...[
                    ProgressBar3D((xp - t.xp) / (next.xp - t.xp), track: AppColors.line, fill: t.color),
                    const SizedBox(height: 6),
                    Text('${next.xp - xp} XP to ${next.name}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black45)),
                  ] else
                    const Text('Highest title reached!', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black45)),
                ]),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < kTitles.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: i <= cur
                      ? duoCard(border: kTitles[i].color)
                      : duoCard(border: AppColors.line, fill: const Color(0xFFF7F7F7), shadow: AppColors.line),
                  child: Row(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: i <= cur ? kTitles[i].color : AppColors.locked, borderRadius: BorderRadius.circular(14)),
                      child: Icon(i <= cur ? kTitles[i].icon : Icons.lock_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(kTitles[i].name,
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: i <= cur ? AppColors.ink : AppColors.lockedShadow)),
                        Text('${kTitles[i].xp} XP', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38)),
                      ]),
                    ),
                    if (i == cur) const Icon(Icons.check_circle_rounded, color: AppColors.success),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
