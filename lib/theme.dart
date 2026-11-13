import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppColors {
  /// Set by the app root (main.dart) before the UI is built. Neutral colours below follow it.
  static bool dark = false;
  static Color _p(Color light, Color dk) => dark ? dk : light;

  static const primary = Color(0xFF00BCEB);
  static const primaryShadow = Color(0xFF0088A8);
  static const secondary = Color(0xFF049FD9);
  static const success = Color(0xFF24C185);
  static const successShadow = Color(0xFF178F62);
  static const error = Color(0xFFFB4B53);
  static const errorShadow = Color(0xFFC93A41);
  static const streak = Color(0xFFFFAE00);
  static const terminalBg = Color(0xFF0D2232);
  static const terminalGreen = Color(0xFF4DFF9A);
  static const streakShadow = Color(0xFFCC8B00);

  // ── neutral colours: light value = the original look, dark value = charcoal grey ──
  static Color get background => _p(const Color(0xFFF4F6F8), const Color(0xFF1E2227)); // app background
  static Color get surface => _p(const Color(0xFFFFFFFF), const Color(0xFF282D33)); // cards, pages, sheets
  static Color get soft => _p(const Color(0xFFF7F7F7), const Color(0xFF2F353C)); // disabled / quiet fill
  static Color get outer => _p(const Color(0xFFE9EDF1), const Color(0xFF15181B)); // area outside the phone-width column
  static Color get ink => _p(const Color(0xFF3C3C3C), const Color(0xFFE8EAED)); // main text
  static Color get line => _p(const Color(0xFFE5E5E5), const Color(0xFF3A4048)); // borders
  static Color get tint => _p(const Color(0xFFDDF4FF), const Color(0xFF1F3A47)); // selected fill
  static Color get tintSoft => _p(const Color(0xFFEAF6FB), const Color(0xFF232A30));
  static Color get locked => _p(const Color(0xFFCBD2D9), const Color(0xFF4A515A));
  static Color get lockedShadow => _p(const Color(0xFF9AA5B1), const Color(0xFF737C88));
  static Color get icon => _p(const Color(0xFFAFAFAF), const Color(0xFF8A93A0)); // back arrows
  static Color get streakTint => _p(const Color(0xFFFFF3D6), const Color(0xFF3B3320));
  static Color get successTint => _p(const Color(0xFFE6F8F0), const Color(0xFF1F3A2F));
  static Color get errorTint => _p(const Color(0xFFFFE5E6), const Color(0xFF3F2629));
  // secondary text (was Colors.black54 / 45 / 38 / 26)
  static Color get mid => _p(const Color(0x8A000000), const Color(0xFFB4BBC3));
  static Color get sub => _p(const Color(0x73000000), const Color(0xFF9AA3AD));
  static Color get faint => _p(const Color(0x61000000), const Color(0xFF7F8893));
  static Color get ghost => _p(const Color(0x42000000), const Color(0xFF555D66));
}

/// Marks every widget dirty so colours that follow [AppColors.dark] are re-read (state is kept).
void rebuildAllElements() {
  void visit(Element e) {
    e.markNeedsBuild();
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
}

/// Spacing / radius scale used across the app.
class AppSpace {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24;
}

class AppRadius {
  static const double sm = 12, md = 16, lg = 24;
}

ThemeData buildTheme({bool dark = false}) {
  final base = TextStyle(fontFamily: 'Nunito', color: dark ? const Color(0xFFE8EAED) : const Color(0xFF1F2933));
  var scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: dark ? Brightness.dark : Brightness.light);
  if (dark) {
    scheme = scheme.copyWith(
      surface: const Color(0xFF282D33),
      onSurface: const Color(0xFFE8EAED),
      surfaceContainerLowest: const Color(0xFF1E2227),
      surfaceContainerLow: const Color(0xFF282D33),
      surfaceContainer: const Color(0xFF2B3036),
      surfaceContainerHigh: const Color(0xFF2F353C),
      surfaceContainerHighest: const Color(0xFF343A41),
    );
  }
  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    fontFamily: 'Nunito',
    splashFactory: NoSplash.splashFactory,
    scaffoldBackgroundColor: dark ? const Color(0xFF1E2227) : const Color(0xFFF4F6F8),
    colorScheme: scheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.secondary,
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
          fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white),
    ),
    textTheme: TextTheme(
      titleLarge: base.copyWith(fontWeight: FontWeight.w700, fontSize: 22),
      bodyLarge: base.copyWith(fontSize: 17),
      bodyMedium: base.copyWith(fontSize: 15),
      labelLarge: base.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
    ),
  );
}

/// Loads assets/icons/<name>.svg (untinted unless [color] is given).
class SvgIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const SvgIcon(this.name, {super.key, this.size = 24, this.color});
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/icons/$name.svg',
        width: size,
        height: size,
        colorFilter: color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
        placeholderBuilder: (_) => SizedBox(width: size, height: size),
      );
}

const codeStyle = TextStyle(fontFamily: 'JetBrainsMono', fontSize: 15, color: AppColors.terminalGreen, height: 1.6);

/// 3D bottom-border button. Height 54dp, radius 16dp. Null onPressed = disabled.
class Button3D extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color, shadow, textColor;
  const Button3D({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.primary,
    this.shadow = AppColors.primaryShadow,
    this.textColor = Colors.white,
  });
  @override
  State<Button3D> createState() => _Button3DState();
}

class _Button3DState extends State<Button3D> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    watchLang(context);
    final enabled = widget.onPressed != null;
    final c = enabled ? widget.color : AppColors.locked;
    final s = enabled ? widget.shadow : AppColors.lockedShadow;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onPressed,
      // Fixed 58dp slot (54 button + 4 ledge) so layout never jumps while pressed.
      child: SizedBox(
        height: 58,
        child: Align(
          alignment: Alignment.topCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            height: 54,
            width: double.infinity,
            transform: Matrix4.translationValues(0, _down ? 4 : 0, 0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: s, offset: Offset(0, _down ? 0 : 4))],
            ),
            child: Text(tr(widget.label).toUpperCase(),
                style: TextStyle(
                    color: enabled ? widget.textColor : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.8)),
          ),
        ),
      ),
    );
  }
}

/// Duolingo-style card: 2dp border + thick bottom ledge.
BoxDecoration duoCard({Color? border, Color? fill, Color? shadow, double radius = 16}) {
  final b = border ?? AppColors.locked;
  return BoxDecoration(
    color: fill ?? AppColors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: b, width: 2),
    boxShadow: [BoxShadow(color: shadow ?? b, offset: const Offset(0, 4))],
  );
}
