// duck_mood.dart  (FILE MỚI)
// Vịt đổi mặt theo thời điểm: lâu không vào -> lo lắng / giận / khóc ...
// Dùng 15 ảnh trong assets/mascot/moods/. Không đụng tới duck.dart (hệ thống vịt mặc đồ).
import 'package:flutter/material.dart' hide Text;
import 'package:hive_flutter/hive_flutter.dart';

import 'i18n.dart';
import 'theme.dart';

enum DuckFace {
  surprised, dizzy, happy, crying, bored, cool, cheer, confused,
  love, sleeping, angry, shy, shocked, determined, worried,
}

const List<String> _faceFiles = [
  'surprised', 'dizzy', 'happy', 'crying', 'bored', 'cool', 'cheer', 'confused',
  'love', 'sleeping', 'angry', 'shy', 'shocked', 'determined', 'worried',
];

String duckFaceAsset(DuckFace f) => 'assets/mascot/moods/duck_${_faceFiles[f.index]}.png';

/// Vịt một biểu cảm, đổi mặt có hiệu ứng. Dùng ở bất cứ đâu (đúng/sai, hoàn thành bài...).
class DuckFaceView extends StatelessWidget {
  final DuckFace face;
  final double size;
  const DuckFaceView({super.key, required this.face, this.size = 140});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
        child: Image.asset(
          duckFaceAsset(face),
          key: ValueKey(face),
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

class WelcomeInfo {
  final DuckFace face;
  final String title;
  final String sub;
  final bool grumpy; // true = vịt đang dỗi, bấm "xin lỗi" trước
  const WelcomeInfo(this.face, this.title, this.sub, {this.grumpy = false});
}

const int _slotMs = 8 * 3600 * 1000; // mỗi 8 giờ đổi một mặt

/// Số thứ tự khung 8 giờ (theo giờ địa phương: 0h-8h, 8h-16h, 16h-24h).
int _slotOf(DateTime now) =>
    (now.millisecondsSinceEpoch + now.timeZoneOffset.inMilliseconds) ~/ _slotMs;

// Công thức đơn giản để widget Android (Kotlin) tính ra CÙNG mặt vịt với app.
int _slotHash(int slot) => (((slot * 2654435761) % 4294967296) ~/ 256) % DuckFace.values.length;

int _faceIndexForSlot(int slot) {
  final n = DuckFace.values.length;
  final cur = _slotHash(slot);
  final prev = _slotHash(slot - 1);
  return cur == prev ? (cur + 1) % n : cur; // không bao giờ trùng khung trước
}

/// Mặt vịt của khung 8 giờ hiện tại (cố định trong khung, đổi sang khung sau).
/// Dùng được ở nơi khác: DuckFaceView(face: currentDuckFace()).
DuckFace currentDuckFace([DateTime? now]) =>
    DuckFace.values[_faceIndexForSlot(_slotOf(now ?? DateTime.now()))];

WelcomeInfo welcomeForFace(DuckFace f) {
  switch (f) {
    case DuckFace.surprised:
      return WelcomeInfo(f, "Whoa, you're here!", 'Perfect timing for a lesson.');
    case DuckFace.dizzy:
      return WelcomeInfo(f, 'My head is spinning...', 'Too many packets today?');
    case DuckFace.happy:
      return WelcomeInfo(f, 'Quack! Hello again!', 'Ready to learn something new?');
    case DuckFace.crying:
      return WelcomeInfo(f, 'Waaah...', 'Even routers have bad days. Please study with me.',
          grumpy: true);
    case DuckFace.bored:
      return WelcomeInfo(f, '...', 'I was getting bored. Quiz me?');
    case DuckFace.cool:
      return WelcomeInfo(f, 'Cool as a firewall.', "Let's ace this exam.");
    case DuckFace.cheer:
      return WelcomeInfo(f, "Let's gooo!", 'Time to level up!');
    case DuckFace.confused:
      return WelcomeInfo(f, 'Wait... which VLAN am I in?', "Let's clear it up with a lesson.");
    case DuckFace.love:
      return WelcomeInfo(f, 'I love studying with you!', "Let's keep that streak going.");
    case DuckFace.sleeping:
      return WelcomeInfo(f, 'Zzz... huh? Oh, hi!', 'A quick lesson before nap time?');
    case DuckFace.angry:
      return WelcomeInfo(f, 'Where have you been?!', "Packets don't route themselves.",
          grumpy: true);
    case DuckFace.shy:
      return WelcomeInfo(f, "Oh! I didn't see you there.", 'Shall we start?');
    case DuckFace.shocked:
      return WelcomeInfo(f, 'Quack?!', 'A wild exam appears!');
    case DuckFace.determined:
      return WelcomeInfo(f, "I'm focused today.", "Let's crush that CCNP.");
    case DuckFace.worried:
      return WelcomeInfo(f, 'Is the network down?', "Let's make sure you're ready.",
          grumpy: true);
  }
}

/// Gọi 1 lần khi mở app. Mỗi khung 8 giờ chỉ hiện popup 1 lần (mở lại trong cùng khung thì thôi).
Future<void> showWelcomeIfNeeded(BuildContext context) async {
  final box = Hive.box('stats');
  final now = DateTime.now();
  final slot = _slotOf(now);
  final raw = box.get('x_lastSlot');
  final last = raw is int ? raw : null;
  if (last == slot) return;
  await box.put('x_lastSlot', slot);
  if (!context.mounted) return;
  final info = welcomeForFace(currentDuckFace(now));
  await showDialog<void>(
    context: context,
    barrierDismissible: !info.grumpy,
    builder: (_) => _WelcomeDialog(info: info),
  );
}

/// Chỉ để TEST: hiện popup của một mặt bất kỳ. Ví dụ previewWelcome(context, DuckFace.angry).
Future<void> previewWelcome(BuildContext context, DuckFace face) async {
  final info = welcomeForFace(face);
  await showDialog<void>(
    context: context,
    barrierDismissible: !info.grumpy,
    builder: (_) => _WelcomeDialog(info: info),
  );
}

class _WelcomeDialog extends StatefulWidget {
  final WelcomeInfo info;
  const _WelcomeDialog({required this.info});
  @override
  State<_WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<_WelcomeDialog> {
  late DuckFace face = widget.info.face;
  late String title = widget.info.title;
  late String sub = widget.info.sub;
  late bool grumpy = widget.info.grumpy;

  void _forgive() {
    setState(() {
      grumpy = false;
      face = DuckFace.love;
      title = 'All is forgiven!';
      sub = "Okay... let's study.";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.line, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DuckFaceView(face: face, size: 170),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 6),
              Text(sub,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: AppColors.ink)),
              const SizedBox(height: 20),
              if (grumpy)
                Button3D(
                  label: "Sorry, I'm back!",
                  onPressed: _forgive,
                  color: AppColors.primary,
                  shadow: AppColors.primaryShadow,
                  textColor: Colors.white,
                )
              else
                Button3D(
                  label: "Let's go",
                  onPressed: () => Navigator.of(context).pop(),
                  color: AppColors.success,
                  shadow: AppColors.successShadow,
                  textColor: Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
