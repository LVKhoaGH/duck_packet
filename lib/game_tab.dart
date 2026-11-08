// game_tab.dart  (FILE MỚI)  Tab "Game": chỗ giữ cho các trò chơi sau này.
import 'package:flutter/material.dart' hide Text;

import 'duck_mood.dart';
import 'i18n.dart';
import 'theme.dart';

class GameTab extends StatelessWidget {
  const GameTab({super.key});

  Widget _locked(IconData icon, String title, String sub) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: duoCard(border: AppColors.line, fill: const Color(0xFFF7F7F7), shadow: AppColors.line),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: AppColors.locked, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.lockedShadow)),
              Text(sub, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black38)),
            ]),
          ),
          const Icon(Icons.lock_rounded, color: AppColors.locked),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      const Text('Game', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.ink)),
      const SizedBox(height: 20),
      const Center(child: DuckFaceView(face: DuckFace.shy, size: 150)),
      const SizedBox(height: 8),
      const Center(
        child: Text('Games are coming soon!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
      ),
      const SizedBox(height: 4),
      const Center(
        child: Text('The duck is still building them.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black38)),
      ),
      const SizedBox(height: 24),
      _locked(Icons.speed_rounded, 'Packet Rush', 'Route packets before time runs out'),
      _locked(Icons.extension_rounded, 'Subnet Puzzle', 'Fit the subnets into the address space'),
      _locked(Icons.shield_rounded, 'Firewall Defense', 'Block the bad traffic, let the good through'),
    ]);
  }
}
