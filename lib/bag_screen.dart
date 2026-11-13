import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bag.dart';
import 'i18n.dart';
import 'sfx.dart';
import 'theme.dart';
import 'widgets.dart';

class ItemInfo {
  final String name, desc;
  final IconData icon;
  final Color color;
  const ItemInfo(this.name, this.desc, this.icon, this.color);
}

ItemInfo itemInfo(String id) {
  switch (id) {
    case 'freeze':
      return const ItemInfo('Streak Freeze', 'Protects your streak when you miss a day. Used automatically.', Icons.ac_unit_rounded, AppColors.primary);
    default:
      return const ItemInfo('XP x2', 'Doubles the XP of your next 3 lessons. Tap Use to activate.', Icons.bolt_rounded, AppColors.streak);
  }
}

/// Shown after tapping a chest on the map.
Future<void> showChestDialog(BuildContext context, ChestReward r) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (_, v, c) => Transform.scale(scale: v, child: c),
              child: const Icon(Icons.card_giftcard_rounded, size: 84, color: AppColors.streak),
            ),
            const SizedBox(height: 6),
            Text('Chest opened!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 14),
            Pop(
              delay: 150,
              child: _rewardRow(const ItemInfo('', '', Icons.bolt_rounded, AppColors.primary), '+${r.xp} XP'),
            ),
            for (var i = 0; i < r.items.length; i++)
              Pop(delay: 300 + i * 150, child: _rewardRow(itemInfo(r.items[i]), '${itemInfo(r.items[i]).name} x1')),
            const SizedBox(height: 16),
            Button3D(label: 'Awesome!', onPressed: () => Navigator.pop(ctx)),
          ]),
        ),
      ),
    );

Widget _rewardRow(ItemInfo i, String text) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: duoCard(border: i.color, radius: 14),
      child: Row(children: [
        Icon(i.icon, color: i.color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink))),
      ]),
    );

class BagScreen extends ConsumerWidget {
  const BagScreen({super.key});

  Widget _item(String id, int count, {String? note, Widget? action}) {
    final i = itemInfo(id);
    final has = count > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: has ? duoCard(border: i.color) : duoCard(border: AppColors.line, fill: AppColors.soft, shadow: AppColors.line),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: has ? i.color : AppColors.locked, borderRadius: BorderRadius.circular(16)),
          child: Icon(i.icon, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(i.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: has ? AppColors.ink : AppColors.lockedShadow)),
              const SizedBox(width: 8),
              Text('x$count', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: has ? i.color : AppColors.lockedShadow)),
            ]),
            Text(i.desc, style: TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w700, color: AppColors.sub)),
            if (note != null) Text(note, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.faint)),
          ]),
        ),
        if (action != null) ...[const SizedBox(width: 8), action],
      ]),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bag = ref.watch(bagProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 4),
            child: Row(children: [
              IconButton(icon: Icon(Icons.arrow_back_rounded, size: 28, color: AppColors.icon), onPressed: () => Navigator.pop(context)),
              Expanded(child: Text('Bag', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink))),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              if (bag.boost > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: duoCard(border: AppColors.streak, fill: AppColors.streakTint, shadow: AppColors.streakShadow),
                  child: Row(children: [
                    const Icon(Icons.bolt_rounded, color: AppColors.streak),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('XP x2 active: ${bag.boost} lessons left',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.streakShadow)),
                    ),
                  ]),
                ),
              _item('freeze', bag.freeze, note: 'Holds up to $kMaxFreeze'),
              _item(
                'xp2',
                bag.xp2,
                action: SizedBox(
                  width: 84,
                  child: Button3D(
                    label: 'Use',
                    color: AppColors.streak,
                    shadow: AppColors.streakShadow,
                    onPressed: bag.xp2 > 0
                        ? () {
                            Sfx.play('tap');
                            ref.read(bagProvider.notifier).useXp2();
                          }
                        : null,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: duoCard(border: AppColors.line, fill: AppColors.soft, shadow: AppColors.line),
                child: Row(children: [
                  Icon(Icons.lock_rounded, color: AppColors.locked),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Duck outfits: coming soon',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.lockedShadow)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Text('Beat a boss, then open the chest at the end of the section to earn items.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.faint)),
            ]),
          ),
        ]),
      ),
    );
  }
}
