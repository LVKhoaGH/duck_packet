import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'i18n.dart';
import 'providers.dart';
import 'sfx.dart';
import 'theme.dart';
import 'widgets.dart';

// ───────────────────────── items ─────────────────────────
class DuckItem {
  final String id, slot, name;
  final Color color; // only used by 'color' items (feather colour)
  const DuckItem(this.id, this.slot, this.name, [this.color = Colors.white]);
}

const kDuckSlots = ['color', 'hat', 'glasses', 'shirt', 'weapon', 'body'];
const kDuckSlotLabel = {
  'color': 'Color',
  'hat': 'Hat',
  'glasses': 'Glasses',
  'shirt': 'Shirt',
  'weapon': 'Weapon',
  'body': 'Body',
};
const kDuckSlotIcon = {
  'color': Icons.palette_rounded,
  'hat': Icons.school_rounded,
  'glasses': Icons.visibility_rounded,
  'shirt': Icons.checkroom_rounded,
  'weapon': Icons.gavel_rounded,
  'body': Icons.fitness_center_rounded,
};

const kDuckItems = <DuckItem>[
  // feathers (white is free)
  DuckItem('white', 'color', 'Snow White', Color(0xFFFFFFFF)),
  DuckItem('cream', 'color', 'Butter', Color(0xFFFFF1B8)),
  DuckItem('pink', 'color', 'Bubblegum', Color(0xFFFFC9DC)),
  DuckItem('mint', 'color', 'Mint', Color(0xFFBDF0D8)),
  DuckItem('sky', 'color', 'Sky', Color(0xFFBFE6FF)),
  DuckItem('lilac', 'color', 'Lilac', Color(0xFFDCCBFF)),
  DuckItem('gold', 'color', 'Golden', Color(0xFFFFD54A)),
  DuckItem('shadow', 'color', 'Shadow', Color(0xFF55616C)),
  // hats
  DuckItem('cap', 'hat', 'Baseball Cap'),
  DuckItem('beanie', 'hat', 'Beanie'),
  DuckItem('crown', 'hat', 'Crown'),
  DuckItem('wizard', 'hat', 'Wizard Hat'),
  DuckItem('tophat', 'hat', 'Top Hat'),
  DuckItem('chef', 'hat', 'Chef Hat'),
  DuckItem('party', 'hat', 'Party Hat'),
  DuckItem('phones', 'hat', 'Headphones'),
  // glasses
  DuckItem('round', 'glasses', 'Round Glasses'),
  DuckItem('shades', 'glasses', 'Cool Shades'),
  DuckItem('square', 'glasses', 'Nerd Glasses'),
  DuckItem('monocle', 'glasses', 'Monocle'),
  // shirts
  DuckItem('tee', 'shirt', 'Blue Tee'),
  DuckItem('hoodie', 'shirt', 'Hoodie'),
  DuckItem('suit', 'shirt', 'Suit & Bow Tie'),
  DuckItem('scarf', 'shirt', 'Red Scarf'),
  DuckItem('jersey', 'shirt', 'Green Jersey'),
  // weapons (held in the right wing)
  DuckItem('sword', 'weapon', 'Steel Sword'),
  DuckItem('hammer', 'weapon', 'War Hammer'),
  DuckItem('axe', 'weapon', 'Battle Axe'),
  DuckItem('staff', 'weapon', 'Magic Staff'),
  DuckItem('trident', 'weapon', 'Trident'),
  DuckItem('dumbbell', 'weapon', 'Dumbbell'),
];

DuckItem? duckItemById(String? id) {
  if (id == null) return null;
  for (final i in kDuckItems) {
    if (i.id == id) return i;
  }
  return null;
}

// ───────────────────────── look ─────────────────────────
enum DuckMood { idle, happy, confused, sleepy }

class DuckLook {
  final Color color;
  final String? hat, glasses, shirt, weapon;
  final int muscle; // 0..6, see kMuscleXp
  const DuckLook({this.color = Colors.white, this.hat, this.glasses, this.shirt, this.weapon, this.muscle = 0});

  DuckLook withMuscle(int m) => DuckLook(color: color, hat: hat, glasses: glasses, shirt: shirt, weapon: weapon, muscle: m);

  DuckLook wearing(DuckItem it) {
    switch (it.slot) {
      case 'color':
        return DuckLook(color: it.color, hat: hat, glasses: glasses, shirt: shirt, weapon: weapon, muscle: muscle);
      case 'hat':
        return DuckLook(color: color, hat: it.id, glasses: glasses, shirt: shirt, weapon: weapon, muscle: muscle);
      case 'glasses':
        return DuckLook(color: color, hat: hat, glasses: it.id, shirt: shirt, weapon: weapon, muscle: muscle);
      case 'weapon':
        return DuckLook(color: color, hat: hat, glasses: glasses, shirt: shirt, weapon: it.id, muscle: muscle);
      default:
        return DuckLook(color: color, hat: hat, glasses: glasses, shirt: it.id, weapon: weapon, muscle: muscle);
    }
  }
}

// ───────────────────────── state (Hive box 'stats', keys x_duck*) ─────────────────────────
class DuckState {
  final String name;
  final Set<String> owned;
  final Map<String, String> wear; // slot -> item id
  final Set<String> awarded; // chapter ids that already gave an item
  const DuckState({this.name = 'Quackers', this.owned = const {'white'}, this.wear = const {}, this.awarded = const {}});

  DuckLook get look => DuckLook(
        color: duckItemById(wear['color'])?.color ?? Colors.white,
        hat: wear['hat'],
        glasses: wear['glasses'],
        shirt: wear['shirt'],
        weapon: wear['weapon'],
      );
}

class DuckNotifier extends Notifier<DuckState> {
  Box get _box => Hive.box('stats');
  final Random _rnd = Random();

  @override
  DuckState build() {
    var name = 'Quackers';
    final n = _box.get('x_duckName');
    if (n is String && n.trim().isNotEmpty) name = n;
    final owned = ((_box.get('x_duckOwned') as List?) ?? const []).map((e) => '$e').toSet()..add('white');
    final awarded = ((_box.get('x_duckAwarded') as List?) ?? const []).map((e) => '$e').toSet();
    final wear = <String, String>{};
    try {
      final raw = _box.get('x_duckWear');
      if (raw is String && raw.isNotEmpty) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) {
          final id = '$v';
          final it = duckItemById(id);
          if (it != null && it.slot == k && owned.contains(id)) wear[k] = id;
        });
      }
    } catch (_) {}
    return DuckState(name: name, owned: owned, wear: wear, awarded: awarded);
  }

  void _save() {
    _box.put('x_duckName', state.name);
    _box.put('x_duckOwned', state.owned.toList());
    _box.put('x_duckWear', jsonEncode(state.wear));
    _box.put('x_duckAwarded', state.awarded.toList());
  }

  void rename(String raw) {
    var n = raw.trim();
    if (n.isEmpty) return;
    if (n.length > 14) n = n.substring(0, 14);
    state = DuckState(name: n, owned: state.owned, wear: state.wear, awarded: state.awarded);
    _save();
  }

  void equip(DuckItem it) {
    if (!state.owned.contains(it.id)) return;
    state = DuckState(name: state.name, owned: state.owned, wear: {...state.wear, it.slot: it.id}, awarded: state.awarded);
    _save();
  }

  void unequip(String slot) {
    if (slot == 'color') return;
    final w = Map<String, String>.from(state.wear)..remove(slot);
    state = DuckState(name: state.name, owned: state.owned, wear: w, awarded: state.awarded);
    _save();
  }

  /// Called when a chapter chest is opened. Gives one random item the user does not own yet.
  /// Returns null when the chapter already gave an item or everything is collected.
  DuckItem? awardForChapter(String chapterId) {
    if (state.awarded.contains(chapterId)) return null;
    final locked = kDuckItems.where((i) => !state.owned.contains(i.id)).toList();
    if (locked.isEmpty) {
      state = DuckState(name: state.name, owned: state.owned, wear: state.wear, awarded: {...state.awarded, chapterId});
      _save();
      return null;
    }
    final it = locked[_rnd.nextInt(locked.length)];
    state = DuckState(
        name: state.name, owned: {...state.owned, it.id}, wear: state.wear, awarded: {...state.awarded, chapterId});
    _save();
    return it;
  }

  /// Progress reset: outfits are cleared, the name stays.
  void reset() {
    for (final k in ['x_duckOwned', 'x_duckWear', 'x_duckAwarded']) {
      _box.delete(k);
    }
    state = DuckState(name: state.name);
  }
}

final duckProvider = NotifierProvider<DuckNotifier, DuckState>(DuckNotifier.new);

// ───────────────────────── muscle (tied to level / title) ─────────────────────────
/// XP needed for each muscle tier. Keep in sync with kTitles in titles.dart (0, 500, 1000, 2500, 5000, 10000, 20000).
const kMuscleXp = [0, 500, 1000, 2500, 5000, 10000, 20000];
const kMuscleNames = ['Chick', 'Slim', 'Fit', 'Strong', 'Buff', 'Ripped', 'Legend'];

/// Highest muscle tier unlocked by this much XP.
int duckUnlockedMuscle(int xp) {
  var m = 0;
  for (var i = 0; i < kMuscleXp.length; i++) {
    if (xp >= kMuscleXp[i]) m = i;
  }
  return m;
}

/// Chosen muscle tier. -1 = automatic (always the highest unlocked). Stored in Hive key x_duckMuscle.
class MuscleNotifier extends Notifier<int> {
  Box get _box => Hive.box('stats');

  @override
  int build() {
    final v = _box.get('x_duckMuscle');
    return v is int ? v : -1;
  }

  void set(int v) {
    state = v;
    _box.put('x_duckMuscle', v);
  }

  void reset() {
    _box.delete('x_duckMuscle');
    state = -1;
  }
}

final duckMuscleProvider = NotifierProvider<MuscleNotifier, int>(MuscleNotifier.new);

/// The duck as it should be drawn right now: outfit + muscle (never above what XP unlocked).
final duckLookProvider = Provider<DuckLook>((ref) {
  final d = ref.watch(duckProvider);
  final xp = ref.watch(statsProvider).xp;
  final sel = ref.watch(duckMuscleProvider);
  final un = duckUnlockedMuscle(xp);
  final m = sel < 0 ? un : min(sel, un);
  return d.look.withMuscle(m);
});

// ───────────────────────── painter ─────────────────────────
Paint _fill(Color c) => Paint()..color = c;
Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Draws the duck in a 200 x 220 design space.
class DuckPainter extends CustomPainter {
  final DuckLook look;
  final DuckMood mood;
  final bool blink;
  const DuckPainter(this.look, {this.mood = DuckMood.idle, this.blink = false});

  static const _ink = Color(0xFF263238);
  static const _beak = Color(0xFFFFA726);
  static const _beakDark = Color(0xFFEF6C00);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 200;
    canvas.save();
    canvas.scale(s, s);
    canvas.translate(0, 22);

    final fe = look.color;
    final line = Color.lerp(fe, const Color(0xFF3C4A57), 0.4)!;
    final m = look.muscle;
    final body = Rect.fromCenter(center: const Offset(100, 134), width: 118.0 + m * 5, height: 100);

    // legend aura
    if (m >= 6) {
      canvas.drawCircle(const Offset(100, 110), 100, _fill(const Color(0x1AFFC107)));
      canvas.drawCircle(const Offset(100, 110), 78, _fill(const Color(0x22FFC107)));
    }

    // ground shadow + feet
    canvas.drawOval(Rect.fromCenter(center: const Offset(100, 192), width: 110, height: 14), _fill(const Color(0x1A000000)));
    for (final x in [76.0, 124.0]) {
      final f = Rect.fromCenter(center: Offset(x, 184), width: 32, height: 16);
      canvas.drawOval(f, _fill(_beak));
      canvas.drawOval(f, _stroke(_beakDark, 2.5));
    }

    // body
    canvas.drawOval(body, _fill(fe));
    _shirt(canvas, body, fe);
    canvas.drawOval(body, _stroke(line, 4));

    // wings
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(100 + side * (56 + m * 2.5), 138);
      canvas.rotate(side * -0.35);
      final ww = 28.0 + m * 3.5;
      final w = Rect.fromCenter(center: Offset.zero, width: ww, height: 52.0 + m * 1.5);
      final wf = _fill(Color.lerp(fe, Colors.black, 0.05)!);
      canvas.drawOval(w, wf);
      canvas.drawOval(w, _stroke(line, 3.5));
      if (m >= 2) {
        final bc = Offset(side * (ww / 2 - 2), -6);
        final br = 5.0 + m * 1.3;
        canvas.drawCircle(bc, br, wf);
        canvas.drawCircle(bc, br, _stroke(line, 3));
      }
      canvas.restore();
    }

    // chest and abs (they show through shirts a little)
    if (m >= 1) {
      final mp = _stroke(line.withAlpha(130), 2.8);
      canvas.drawArc(Rect.fromCenter(center: const Offset(84, 134), width: 36, height: 26), 0.1, 2.4, false, mp);
      canvas.drawArc(Rect.fromCenter(center: const Offset(116, 134), width: 36, height: 26), 0.64, 2.4, false, mp);
    }
    if (m >= 3) {
      final ap = _stroke(line.withAlpha(110), 2.5);
      canvas.drawLine(const Offset(100, 150), const Offset(100, 178), ap);
      canvas.drawLine(const Offset(88, 158), const Offset(112, 158), ap);
      canvas.drawLine(const Offset(89, 168), const Offset(111, 168), ap);
    }

    // scarf goes under the head
    if (look.shirt == 'scarf') _scarf(canvas);

    // head
    const hc = Offset(100, 72);
    canvas.drawCircle(hc, 42, _fill(fe));
    canvas.drawCircle(hc, 42, _stroke(line, 4));

    // tuft (hidden under tall hats)
    if (look.hat == null || look.hat == 'phones') {
      canvas.drawPath(
          Path()
            ..moveTo(98, 31)
            ..quadraticBezierTo(94, 18, 104, 14),
          _stroke(line, 4));
      canvas.drawPath(
          Path()
            ..moveTo(106, 31)
            ..quadraticBezierTo(108, 22, 116, 21),
          _stroke(line, 4));
    }

    // cheeks
    canvas.drawCircle(const Offset(66, 86), 7, _fill(const Color(0x59FF6E6E)));
    canvas.drawCircle(const Offset(134, 86), 7, _fill(const Color(0x59FF6E6E)));

    _beakAndMouth(canvas);
    _eyes(canvas);
    _glasses(canvas);
    _hat(canvas, line);
    _weapon(canvas);

    canvas.restore();
  }

  void _beakAndMouth(Canvas canvas) {
    if (mood == DuckMood.happy) {
      canvas.drawOval(Rect.fromCenter(center: const Offset(100, 100), width: 26, height: 12), _fill(_beakDark));
    }
    final up = Rect.fromCenter(center: const Offset(100, 90), width: 40, height: 24);
    canvas.drawOval(up, _fill(_beak));
    canvas.drawOval(up, _stroke(_beakDark, 3));
    if (mood == DuckMood.idle || mood == DuckMood.sleepy) {
      canvas.drawLine(const Offset(88, 93), const Offset(112, 93), _stroke(_beakDark, 2.5));
    } else if (mood == DuckMood.confused) {
      canvas.drawLine(const Offset(88, 95), const Offset(112, 91), _stroke(_beakDark, 2.5));
    }
  }

  void _eyes(Canvas canvas) {
    const l = Offset(82, 66), r = Offset(118, 66);
    if (mood == DuckMood.happy) {
      for (final c in [l, r]) {
        canvas.drawArc(Rect.fromCenter(center: c.translate(0, 3), width: 16, height: 14), pi, pi, false, _stroke(_ink, 4.5));
      }
    } else if (blink || mood == DuckMood.sleepy) {
      for (final c in [l, r]) {
        canvas.drawLine(c.translate(-7, 0), c.translate(7, 0), _stroke(_ink, 4.5));
      }
    } else {
      final conf = mood == DuckMood.confused;
      final lr = conf ? 5.0 : 6.0;
      final rr = conf ? 8.0 : 6.0;
      canvas.drawOval(Rect.fromCenter(center: l, width: lr * 2, height: lr * 2.4), _fill(_ink));
      canvas.drawOval(Rect.fromCenter(center: r, width: rr * 2, height: rr * 2.4), _fill(_ink));
      canvas.drawCircle(l.translate(1.8, -2.5), 2.2, _fill(Colors.white));
      canvas.drawCircle(r.translate(1.8, -2.5), 2.2, _fill(Colors.white));
      if (!conf && look.muscle >= 4) {
        canvas.drawLine(const Offset(70, 52), const Offset(92, 59), _stroke(_ink, 4.5));
        canvas.drawLine(const Offset(130, 52), const Offset(108, 59), _stroke(_ink, 4.5));
      }
      if (conf) {
        canvas.drawLine(const Offset(72, 52), const Offset(92, 47), _stroke(_ink, 3.5));
        canvas.drawLine(const Offset(108, 49), const Offset(128, 55), _stroke(_ink, 3.5));
      }
    }
  }

  void _glasses(Canvas canvas) {
    const l = Offset(82, 66), r = Offset(118, 66);
    switch (look.glasses) {
      case 'round':
        for (final c in [l, r]) {
          canvas.drawCircle(c, 14, _fill(const Color(0x33FFFFFF)));
          canvas.drawCircle(c, 14, _stroke(_ink, 3.5));
        }
        canvas.drawLine(const Offset(96, 64), const Offset(104, 64), _stroke(_ink, 3.5));
        break;
      case 'shades':
        final rl = RRect.fromRectAndRadius(Rect.fromLTWH(66, 55, 32, 22), const Radius.circular(8));
        final rr = RRect.fromRectAndRadius(Rect.fromLTWH(102, 55, 32, 22), const Radius.circular(8));
        canvas.drawRRect(rl, _fill(const Color(0xFF212121)));
        canvas.drawRRect(rr, _fill(const Color(0xFF212121)));
        canvas.drawLine(const Offset(98, 62), const Offset(102, 62), _stroke(const Color(0xFF212121), 4));
        canvas.drawLine(const Offset(72, 60), const Offset(78, 60), _stroke(const Color(0x66FFFFFF), 3));
        canvas.drawLine(const Offset(108, 60), const Offset(114, 60), _stroke(const Color(0x66FFFFFF), 3));
        break;
      case 'square':
        const col = Color(0xFFE53935);
        for (final x in [66.0, 102.0]) {
          final rc = RRect.fromRectAndRadius(Rect.fromLTWH(x, 54, 32, 24), const Radius.circular(5));
          canvas.drawRRect(rc, _fill(const Color(0x33FFFFFF)));
          canvas.drawRRect(rc, _stroke(col, 3.5));
        }
        canvas.drawLine(const Offset(98, 62), const Offset(102, 62), _stroke(col, 3.5));
        break;
      case 'monocle':
        canvas.drawCircle(r, 15, _fill(const Color(0x33FFFFFF)));
        canvas.drawCircle(r, 15, _stroke(const Color(0xFFFFB300), 3.5));
        canvas.drawPath(
            Path()
              ..moveTo(130, 76)
              ..quadraticBezierTo(142, 100, 138, 120),
            _stroke(const Color(0xFFFFB300), 2));
        break;
      default:
        break;
    }
  }

  void _shirt(Canvas canvas, Rect body, Color fe) {
    final id = look.shirt;
    if (id == null || id == 'scarf') return;
    canvas.save();
    canvas.clipPath(Path()..addOval(body));
    switch (id) {
      case 'tee':
        canvas.drawRect(const Rect.fromLTWH(10, 114, 180, 100), _fill(const Color(0xFF29B6F6)));
        canvas.drawOval(Rect.fromCenter(center: const Offset(100, 112), width: 46, height: 24), _fill(fe));
        break;
      case 'hoodie':
        canvas.drawRect(const Rect.fromLTWH(10, 110, 180, 100), _fill(const Color(0xFFFF8A65)));
        canvas.drawOval(Rect.fromCenter(center: const Offset(100, 110), width: 56, height: 28), _fill(const Color(0xFFF4511E)));
        canvas.drawOval(Rect.fromCenter(center: const Offset(100, 111), width: 40, height: 20), _fill(fe));
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(74, 150, 52, 24), const Radius.circular(8)), _fill(const Color(0xFFF4511E)));
        canvas.drawLine(const Offset(90, 120), const Offset(90, 138), _stroke(Colors.white, 3));
        canvas.drawLine(const Offset(110, 120), const Offset(110, 138), _stroke(Colors.white, 3));
        break;
      case 'suit':
        canvas.drawRect(const Rect.fromLTWH(10, 112, 180, 100), _fill(const Color(0xFF37474F)));
        canvas.drawPath(
            Path()
              ..moveTo(82, 112)
              ..lineTo(118, 112)
              ..lineTo(100, 156)
              ..close(),
            _fill(Colors.white));
        canvas.drawPath(
            Path()
              ..moveTo(100, 120)
              ..lineTo(80, 111)
              ..lineTo(80, 129)
              ..close(),
            _fill(const Color(0xFFE53935)));
        canvas.drawPath(
            Path()
              ..moveTo(100, 120)
              ..lineTo(120, 111)
              ..lineTo(120, 129)
              ..close(),
            _fill(const Color(0xFFE53935)));
        canvas.drawCircle(const Offset(100, 120), 4.5, _fill(const Color(0xFFB71C1C)));
        break;
      case 'jersey':
        canvas.drawRect(const Rect.fromLTWH(10, 114, 180, 100), _fill(const Color(0xFF43A047)));
        canvas.drawRect(const Rect.fromLTWH(10, 140, 180, 8), _fill(Colors.white));
        canvas.drawRect(const Rect.fromLTWH(10, 156, 180, 8), _fill(Colors.white));
        canvas.drawOval(Rect.fromCenter(center: const Offset(100, 112), width: 46, height: 24), _fill(fe));
        break;
      default:
        break;
    }
    canvas.restore();
  }

  void _scarf(Canvas canvas) {
    const red = Color(0xFFE53935);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(112, 118, 20, 44), const Radius.circular(8)), _fill(const Color(0xFFC62828)));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(52, 104, 96, 22), const Radius.circular(11)), _fill(red));
    canvas.drawLine(const Offset(70, 106), const Offset(70, 124), _stroke(const Color(0xFFFFCDD2), 3));
    canvas.drawLine(const Offset(130, 106), const Offset(130, 124), _stroke(const Color(0xFFFFCDD2), 3));
  }

  void _weapon(Canvas canvas) {
    final id = look.weapon;
    if (id == null) return;
    final hand = Offset(100 + (56 + look.muscle * 2.5) + 8, 150);
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate(-0.22);
    const wood = Color(0xFF8D6E63);
    const steel = Color(0xFFCFD8DC);
    const steelDark = Color(0xFF607D8B);
    switch (id) {
      case 'sword':
        final blade = Path()
          ..moveTo(-4, -8)
          ..lineTo(-4, -58)
          ..lineTo(0, -72)
          ..lineTo(4, -58)
          ..lineTo(4, -8)
          ..close();
        canvas.drawPath(blade, _fill(steel));
        canvas.drawPath(blade, _stroke(steelDark, 2));
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-13, -9, 26, 6), const Radius.circular(2)), _fill(const Color(0xFFFFC107)));
        canvas.drawRect(const Rect.fromLTWH(-3, -3, 6, 16), _fill(wood));
        canvas.drawCircle(const Offset(0, 15), 3.8, _fill(const Color(0xFFFFC107)));
        break;
      case 'hammer':
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-3, -52, 6, 74), const Radius.circular(3)), _fill(wood));
        final head = RRect.fromRectAndRadius(const Rect.fromLTWH(-19, -66, 38, 22), const Radius.circular(5));
        canvas.drawRRect(head, _fill(const Color(0xFF78909C)));
        canvas.drawRRect(head, _stroke(const Color(0xFF37474F), 2.5));
        break;
      case 'axe':
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-3, -56, 6, 78), const Radius.circular(3)), _fill(wood));
        final blade = Path()
          ..moveTo(3, -58)
          ..lineTo(24, -68)
          ..quadraticBezierTo(34, -48, 24, -32)
          ..lineTo(3, -40)
          ..close();
        canvas.drawPath(blade, _fill(const Color(0xFF90A4AE)));
        canvas.drawPath(blade, _stroke(const Color(0xFF37474F), 2.5));
        break;
      case 'staff':
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-2.5, -70, 5, 94), const Radius.circular(2.5)), _fill(wood));
        canvas.drawCircle(const Offset(0, -78), 13, _fill(const Color(0x337E57C2)));
        canvas.drawCircle(const Offset(0, -78), 9, _fill(const Color(0xFF7E57C2)));
        canvas.drawCircle(const Offset(-3, -81), 2.6, _fill(Colors.white));
        break;
      case 'trident':
        final tp = _stroke(const Color(0xFF29B6F6), 3.5);
        canvas.drawLine(const Offset(0, 20), const Offset(0, -62), _stroke(steelDark, 4));
        canvas.drawLine(const Offset(-11, -52), const Offset(11, -52), tp);
        canvas.drawLine(const Offset(0, -52), const Offset(0, -76), tp);
        canvas.drawLine(const Offset(-11, -52), const Offset(-11, -70), tp);
        canvas.drawLine(const Offset(11, -52), const Offset(11, -70), tp);
        break;
      case 'dumbbell':
        canvas.rotate(0.22);
        canvas.translate(0, -14);
        canvas.drawLine(const Offset(-17, 0), const Offset(17, 0), _stroke(steelDark, 5));
        for (final x in [-27.0, 17.0]) {
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, -11, 10, 22), const Radius.circular(3)), _fill(const Color(0xFF37474F)));
        }
        break;
      default:
        break;
    }
    canvas.restore();
  }

  void _hat(Canvas canvas, Color line) {
    switch (look.hat) {
      case 'cap':
        final dome = Path()
          ..moveTo(60, 50)
          ..quadraticBezierTo(58, 10, 100, 10)
          ..quadraticBezierTo(142, 10, 140, 50)
          ..close();
        canvas.drawPath(dome, _fill(const Color(0xFF1E88E5)));
        canvas.drawPath(dome, _stroke(const Color(0xFF0D47A1), 3));
        final brim = Rect.fromCenter(center: const Offset(100, 50), width: 104, height: 14);
        canvas.drawOval(brim, _fill(const Color(0xFF1565C0)));
        canvas.drawOval(brim, _stroke(const Color(0xFF0D47A1), 3));
        canvas.drawCircle(const Offset(100, 10), 4, _fill(const Color(0xFF0D47A1)));
        break;
      case 'beanie':
        final dome = Path()
          ..moveTo(58, 52)
          ..quadraticBezierTo(56, 12, 100, 12)
          ..quadraticBezierTo(144, 12, 142, 52)
          ..close();
        canvas.drawPath(dome, _fill(const Color(0xFFE53935)));
        canvas.drawPath(dome, _stroke(const Color(0xFFB71C1C), 3));
        final band = RRect.fromRectAndRadius(const Rect.fromLTWH(56, 40, 88, 15), const Radius.circular(7));
        canvas.drawRRect(band, _fill(const Color(0xFFC62828)));
        canvas.drawRRect(band, _stroke(const Color(0xFFB71C1C), 2.5));
        canvas.drawCircle(const Offset(100, 8), 9, _fill(Colors.white));
        canvas.drawCircle(const Offset(100, 8), 9, _stroke(const Color(0xFFCFD8DC), 2.5));
        break;
      case 'crown':
        final p = Path()
          ..moveTo(64, 46)
          ..lineTo(62, 14)
          ..lineTo(82, 30)
          ..lineTo(100, 6)
          ..lineTo(118, 30)
          ..lineTo(138, 14)
          ..lineTo(136, 46)
          ..close();
        canvas.drawPath(p, _fill(const Color(0xFFFFC107)));
        canvas.drawPath(p, _stroke(const Color(0xFFFF8F00), 3));
        canvas.drawCircle(const Offset(100, 34), 4.5, _fill(const Color(0xFFE53935)));
        canvas.drawCircle(const Offset(78, 38), 3.5, _fill(const Color(0xFF29B6F6)));
        canvas.drawCircle(const Offset(122, 38), 3.5, _fill(const Color(0xFF29B6F6)));
        break;
      case 'wizard':
        final cone = Path()
          ..moveTo(62, 48)
          ..quadraticBezierTo(92, 20, 108, -16)
          ..quadraticBezierTo(122, 20, 138, 48)
          ..close();
        canvas.drawPath(cone, _fill(const Color(0xFF7E57C2)));
        canvas.drawPath(cone, _stroke(const Color(0xFF4527A0), 3));
        final brim = Rect.fromCenter(center: const Offset(100, 48), width: 112, height: 16);
        canvas.drawOval(brim, _fill(const Color(0xFF5E35B1)));
        canvas.drawOval(brim, _stroke(const Color(0xFF4527A0), 3));
        canvas.drawCircle(const Offset(94, 26), 3.2, _fill(const Color(0xFFFFEE58)));
        canvas.drawCircle(const Offset(108, 8), 2.6, _fill(const Color(0xFFFFEE58)));
        canvas.drawCircle(const Offset(110, 34), 2.2, _fill(const Color(0xFFFFEE58)));
        break;
      case 'tophat':
        final cyl = RRect.fromRectAndRadius(const Rect.fromLTWH(72, 2, 56, 46), const Radius.circular(4));
        canvas.drawRRect(cyl, _fill(const Color(0xFF263238)));
        canvas.drawRect(const Rect.fromLTWH(72, 32, 56, 9), _fill(const Color(0xFFE53935)));
        final brim = Rect.fromCenter(center: const Offset(100, 48), width: 96, height: 14);
        canvas.drawOval(brim, _fill(const Color(0xFF1C262B)));
        break;
      case 'chef':
        final white = _fill(Colors.white);
        final edge = _stroke(const Color(0xFFCFD8DC), 3);
        for (final c in [const Offset(78, 24), const Offset(122, 24), const Offset(100, 12)]) {
          canvas.drawCircle(c, 19, white);
        }
        for (final c in [const Offset(78, 24), const Offset(122, 24), const Offset(100, 12)]) {
          canvas.drawCircle(c, 19, edge);
        }
        for (final c in [const Offset(78, 24), const Offset(122, 24), const Offset(100, 12)]) {
          canvas.drawCircle(c, 17, white);
        }
        final band = RRect.fromRectAndRadius(const Rect.fromLTWH(74, 32, 52, 18), const Radius.circular(4));
        canvas.drawRRect(band, white);
        canvas.drawRRect(band, edge);
        break;
      case 'party':
        final cone = Path()
          ..moveTo(72, 48)
          ..lineTo(100, -10)
          ..lineTo(128, 48)
          ..close();
        canvas.drawPath(cone, _fill(const Color(0xFFEC407A)));
        canvas.drawPath(cone, _stroke(const Color(0xFFC2185B), 3));
        canvas.drawOval(Rect.fromCenter(center: const Offset(100, 48), width: 56, height: 10), _fill(const Color(0xFFC2185B)));
        canvas.drawCircle(const Offset(94, 28), 3.2, _fill(const Color(0xFFFFEE58)));
        canvas.drawCircle(const Offset(108, 16), 3, _fill(const Color(0xFF80DEEA)));
        canvas.drawCircle(const Offset(106, 38), 3, _fill(const Color(0xFFFFEE58)));
        canvas.drawCircle(const Offset(100, -10), 6, _fill(const Color(0xFFFFEE58)));
        break;
      case 'phones':
        canvas.drawArc(Rect.fromCenter(center: const Offset(100, 72), width: 96, height: 96), pi, pi, false, _stroke(const Color(0xFF455A64), 7));
        for (final x in [38.0, 144.0]) {
          final cup = RRect.fromRectAndRadius(Rect.fromLTWH(x, 58, 18, 34), const Radius.circular(8));
          canvas.drawRRect(cup, _fill(const Color(0xFFFF5252)));
          canvas.drawRRect(cup, _stroke(const Color(0xFFB71C1C), 3));
        }
        break;
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(DuckPainter old) =>
      old.look.color != look.color ||
      old.look.hat != look.hat ||
      old.look.glasses != look.glasses ||
      old.look.shirt != look.shirt ||
      old.look.weapon != look.weapon ||
      old.look.muscle != look.muscle ||
      old.mood != mood ||
      old.blink != blink;
}

// ───────────────────────── interactive widget ─────────────────────────
/// The mascot. Idles (bobbing + blinking) and hops when tapped. Reads the outfit from [duckProvider]
/// unless [look] is given.
class DuckView extends ConsumerStatefulWidget {
  final double size;
  final DuckMood mood;
  final VoidCallback? onTap;
  final DuckLook? look;
  const DuckView({super.key, this.size = 120, this.mood = DuckMood.idle, this.onTap, this.look});
  @override
  ConsumerState<DuckView> createState() => _DuckViewState();
}

class _DuckViewState extends ConsumerState<DuckView> with TickerProviderStateMixin {
  late final AnimationController _bob =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..repeat(reverse: true);
  late final AnimationController _hop = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  Timer? _t;
  bool _blink = false;
  final Random _rnd = Random();

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    _t = Timer(Duration(milliseconds: 2200 + _rnd.nextInt(3200)), () async {
      if (!mounted) return;
      setState(() => _blink = true);
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() => _blink = false);
      _schedule();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _bob.dispose();
    _hop.dispose();
    super.dispose();
  }

  void _poke() {
    Sfx.play('tap');
    _hop.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final DuckLook look = widget.look ?? ref.watch(duckLookProvider);
    final sz = widget.size;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _poke,
      child: AnimatedBuilder(
        animation: Listenable.merge([_bob, _hop]),
        builder: (_, __) {
          final b = Curves.easeInOut.transform(_bob.value);
          final h = sin(pi * _hop.value) * sz * 0.2;
          return Transform.translate(
            offset: Offset(0, -h - b * sz * 0.03),
            child: SizedBox(
              width: sz,
              height: sz * 1.1,
              child: CustomPaint(
                painter: DuckPainter(look, mood: _hop.isAnimating ? DuckMood.happy : widget.mood, blink: _blink),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────── wardrobe screen ─────────────────────────
class DuckScreen extends ConsumerStatefulWidget {
  const DuckScreen({super.key});
  @override
  ConsumerState<DuckScreen> createState() => _DuckScreenState();
}

class _DuckScreenState extends ConsumerState<DuckScreen> {
  String _slot = 'color';

  Future<void> _rename() async {
    final cur = ref.read(duckProvider).name;
    final res = await showDialog<String>(context: context, builder: (_) => _RenameDialog(initial: cur));
    if (res != null) ref.read(duckProvider.notifier).rename(res);
  }

  Widget _preview(DuckLook look, bool dim) => Opacity(
        opacity: dim ? 0.3 : 1,
        child: LayoutBuilder(builder: (_, bc) {
          final w = min(bc.maxWidth, bc.maxHeight / 1.1);
          return Center(child: CustomPaint(size: Size(w, w * 1.1), painter: DuckPainter(look)));
        }),
      );

  Widget _cell({required Widget child, required String label, required bool worn, required bool locked, required VoidCallback onTap}) =>
      PressScale(
        scale: 0.96,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          decoration: worn
              ? duoCard(border: AppColors.primary, fill: AppColors.tint, shadow: AppColors.primaryShadow, radius: 16)
              : duoCard(radius: 16),
          child: Column(children: [
            Expanded(
              child: Stack(alignment: Alignment.center, children: [
                child,
                if (locked) const Icon(Icons.lock_rounded, color: AppColors.lockedShadow, size: 26),
              ]),
            ),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: locked ? Colors.black38 : AppColors.ink)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(duckProvider);
    final notifier = ref.read(duckProvider.notifier);
    final items = kDuckItems.where((i) => i.slot == _slot).toList();
    final totalLocked = kDuckItems.length - 1;
    final got = d.owned.where((e) => e != 'white').length;
    final xp = ref.watch(statsProvider).xp;
    final sel = ref.watch(duckMuscleProvider);
    final wornId = d.wear[_slot] ?? (_slot == 'color' ? 'white' : null);

    final itemCells = <Widget>[
      if (_slot != 'color' && _slot != 'body')
        _cell(
          child: const Icon(Icons.block_rounded, size: 40, color: AppColors.locked),
          label: 'None',
          worn: wornId == null,
          locked: false,
          onTap: () {
            Sfx.play('tap');
            notifier.unequip(_slot);
          },
        ),
      for (final it in items)
        _cell(
          child: _preview(const DuckLook().wearing(it), !d.owned.contains(it.id)),
          label: d.owned.contains(it.id) ? it.name : '???',
          worn: wornId == it.id,
          locked: !d.owned.contains(it.id),
          onTap: () {
            if (!d.owned.contains(it.id)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open a chapter chest to unlock this')));
              return;
            }
            Sfx.play('tap');
            if (wornId == it.id && it.slot != 'color') {
              notifier.unequip(it.slot);
            } else {
              notifier.equip(it);
            }
          },
        ),
    ];

    final un = duckUnlockedMuscle(xp);
    final curM = sel < 0 ? un : min(sel, un);
    final bodyCells = <Widget>[
      for (var i = 0; i < kMuscleXp.length; i++)
        _cell(
          child: _preview(d.look.withMuscle(i), i > un),
          label: i <= un ? kMuscleNames[i] : '${kMuscleXp[i]} XP',
          worn: i == curM,
          locked: i > un,
          onTap: () {
            if (i > un) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Earn more XP to unlock this body')));
              return;
            }
            Sfx.play('tap');
            ref.read(duckMuscleProvider.notifier).set(i == un ? -1 : i);
          },
        ),
    ];
    final cells = _slot == 'body' ? bodyCells : itemCells;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
          Row(children: [
            IconButton(icon: const Icon(Icons.close_rounded, size: 30, color: Color(0xFFAFAFAF)), onPressed: () => Navigator.pop(context)),
            const Expanded(
              child: Text('My Duck',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
            ),
            const SizedBox(width: 48),
          ]),
          const SizedBox(height: 4),
          Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: duoCard(border: AppColors.line, fill: AppColors.tint, radius: 24),
              child: Center(child: DuckView(size: 180, mood: DuckMood.happy)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _rename,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                  child: Text(d.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.ink)),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.edit_rounded, size: 22, color: AppColors.secondary),
              ]),
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text('$got / $totalLocked unlocked  ·  new items drop from chapter chests',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38)),
          ),
          const SizedBox(height: 16),
          Row(children: [
            for (final s in kDuckSlots)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: s == kDuckSlots.last ? 0 : 6),
                  child: PressScale(
                    onTap: () {
                      Sfx.play('tap');
                      setState(() => _slot = s);
                    },
                    child: Container(
                      height: 58,
                      decoration: _slot == s
                          ? duoCard(border: AppColors.primary, fill: AppColors.tint, shadow: AppColors.primaryShadow, radius: 14)
                          : duoCard(radius: 14),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(kDuckSlotIcon[s], size: 24, color: _slot == s ? AppColors.primary : AppColors.locked),
                        Text(kDuckSlotLabel[s] ?? s,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _slot == s ? AppColors.primaryShadow : Colors.black45)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.82,
            children: cells,
          ),
        ]),
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  final String initial;
  const _RenameDialog({required this.initial});
  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Name your duck'),
        content: TextField(
          controller: _c,
          autofocus: true,
          maxLength: 14,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: tr('Duck name')),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, _c.text), child: const Text('SAVE')),
        ],
      );
}

// ───────────────────────── unlock dialog (after opening a chapter chest) ─────────────────────────
Future<void> showDuckUnlock(BuildContext context, WidgetRef ref, DuckItem item) {
  final look = ref.read(duckLookProvider).wearing(item);
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('NEW DUCK ITEM!',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.streakShadow)),
          const SizedBox(height: 10),
          CustomPaint(size: const Size(150, 165), painter: DuckPainter(look, mood: DuckMood.happy)),
          const SizedBox(height: 8),
          Text(item.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink)),
          Text(kDuckSlotLabel[item.slot] ?? item.slot,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black38)),
          const SizedBox(height: 16),
          Button3D(
            label: 'Wear it',
            onPressed: () {
              ref.read(duckProvider.notifier).equip(item);
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 4),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
        ]),
      ),
    ),
  );
}
