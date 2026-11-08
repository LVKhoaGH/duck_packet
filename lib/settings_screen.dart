import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_chat.dart';
import 'extras.dart';
import 'i18n.dart';
import 'settings.dart';
import 'sfx.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Widget _switch(IconData icon, String title, bool v, ValueChanged<bool> on) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: duoCard(border: AppColors.line),
        child: Row(children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink))),
          Switch(value: v, activeColor: Colors.white, activeTrackColor: AppColors.success, onChanged: on),
        ]),
      );

  Widget _chip(String label, bool sel, VoidCallback onTap) => Expanded(
        child: PressScale(
          onTap: onTap,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: sel
                ? duoCard(border: AppColors.primary, fill: AppColors.tint, shadow: AppColors.primaryShadow, radius: 12)
                : duoCard(radius: 12),
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: sel ? AppColors.primaryShadow : Colors.black45)),
          ),
        ),
      );

  Widget _head(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.secondary)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final goal = ref.watch(extrasProvider).goal;
    final n = ref.read(settingsProvider.notifier);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 4),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 28, color: Color(0xFFAFAFAF)), onPressed: () => Navigator.pop(context)),
              const Expanded(child: Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink))),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
              _head('Sound'),
              _switch(Icons.volume_up_rounded, 'Sound effects', s.sound, (v) {
                n.setSound(v);
                if (v) Sfx.play('tap');
              }),
              _switch(Icons.vibration_rounded, 'Vibration', s.haptics, (v) => n.setHaptics(v)),
              _head('Language'),
              Row(children: [
                _chip('English', s.lang == 'en', () => n.setLang('en')),
                const SizedBox(width: 10),
                _chip('Tiếng Việt', s.lang == 'vi', () => n.setLang('vi')),
              ]),
              _head('Daily goal'),
              Row(children: [
                for (final g in kGoalOptions) ...[
                  _chip('$g XP', goal == g, () {
                    Sfx.play('tap');
                    ref.read(extrasProvider.notifier).setGoal(g);
                  }),
                  if (g != kGoalOptions.last) const SizedBox(width: 10),
                ],
              ]),
              _head('AI assistant'),
              PressScale(
                onTap: () => showAiSheet(context),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                  decoration: duoCard(border: AppColors.line),
                  child: Row(children: [
                    const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Expanded(
                        child: Text('Gemini API key & chat',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink))),
                    const Icon(Icons.chevron_right_rounded, color: Colors.black38),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
