import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Fire-and-forget sound effects (a fresh player per call so sounds can overlap).
/// Respects the Settings switches (x_sound, x_haptics).
class Sfx {
  static Box get _b => Hive.box('stats');
  static bool get soundOn => _b.get('x_sound', defaultValue: true) != false;
  static bool get hapticsOn => _b.get('x_haptics', defaultValue: true) != false;

  /// Vibrate only if haptics are enabled: Sfx.buzz(HapticFeedback.heavyImpact)
  static void buzz(Future<void> Function() f) {
    if (hapticsOn) f();
  }

  static Future<void> play(String name) async {
    if (name == 'tap') buzz(HapticFeedback.selectionClick);
    if (!soundOn) return;
    final p = AudioPlayer();
    p.onPlayerComplete.first.then((_) => p.dispose());
    try {
      await p.play(AssetSource('audio/$name.mp3'));
    } catch (_) {
      p.dispose();
    }
  }
}
