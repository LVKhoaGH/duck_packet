import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_chat.dart';
import 'providers.dart' show dayKey;
import 'reminders.dart';
import 'widget_sync.dart';
import 'extras.dart';
import 'i18n.dart';
import 'settings.dart';
import 'sfx.dart';
import 'theme.dart';
import 'tracks.dart';
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
          Switch(value: v, activeThumbColor: Colors.white, activeTrackColor: AppColors.success, onChanged: on),
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

  void _snack(BuildContext c, String t) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(t)));

  Widget _remRow(IconData icon, String title, String value, VoidCallback onTap) => PressScale(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          decoration: duoCard(border: AppColors.line),
          child: Row(children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink))),
            if (value.isNotEmpty) Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryShadow)),
            const Icon(Icons.chevron_right_rounded, color: Colors.black38),
          ]),
        ),
      );

  List<Widget> _reminders(BuildContext context, WidgetRef ref) {
    final r = ref.watch(reminderProvider);
    final rn = ref.read(reminderProvider.notifier);
    return [
      _head('Study reminders'),
      _switch(Icons.notifications_active_rounded, 'Study reminders', r.enabled, (v) async {
        final ok = await rn.setEnabled(v);
        if (v && !ok && context.mounted) {
          _snack(context, 'Notifications are blocked. Allow them in your browser or phone settings.');
        }
      }),
      if (r.enabled) ...[
        _remRow(Icons.schedule_rounded, 'Remind me at', TimeOfDay(hour: r.hour, minute: r.minute).format(context), () async {
          final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: r.hour, minute: r.minute));
          if (t != null) await rn.setMinutes(t.hour * 60 + t.minute);
        }),
        _switch(Icons.local_fire_department_rounded, 'Warn me before I lose my streak', r.rescue, (v) => rn.setRescue(v)),
        _remRow(Icons.send_rounded, 'Send a test notification', '', () => rn.testNow()),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Text('Reminders on Android and iPhone work even when the app is closed. On web and Windows the app must stay open.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38)),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final goal = ref.watch(extrasProvider).goal;
    final n = ref.read(settingsProvider.notifier);
    final track = trackOf(ref.watch(trackProvider));
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
              _head('Course'),
              PressScale(
                onTap: () => Navigator.push(context, slideUpRoute(const TrackPickerScreen())),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                  decoration: duoCard(border: AppColors.line),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: track.color, borderRadius: BorderRadius.circular(12)),
                      child: Icon(track.icon, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(track.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        const Text('Tap to switch course', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.black38),
                  ]),
                ),
              ),
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
              _head('Exam date'),
              PressScale(
                onTap: () async {
                  final now = DateTime.now();
                  final first = DateTime(now.year, now.month, now.day);
                  final cur = DateTime.tryParse(ref.read(examDateProvider));
                  final d = await showDatePicker(
                    context: context,
                    initialDate: (cur != null && !cur.isBefore(first)) ? cur : first.add(const Duration(days: 30)),
                    firstDate: first,
                    lastDate: first.add(const Duration(days: 1095)),
                  );
                  if (d != null) await setExamDate(ref, dayKey(d));
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                  decoration: duoCard(border: AppColors.line),
                  child: Row(children: [
                    const Icon(Icons.event_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(ref.watch(examDateProvider).isEmpty ? 'Not set' : ref.watch(examDateProvider),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    ),
                    if (ref.watch(examDateProvider).isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.black38),
                        onPressed: () => setExamDate(ref, ''),
                      )
                    else
                      const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.chevron_right_rounded, color: Colors.black38)),
                  ]),
                ),
              ),
              ..._reminders(context, ref),
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
