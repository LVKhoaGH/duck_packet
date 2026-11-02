import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppColors {
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
  static const background = Color(0xFFF4F6F8);
  static const locked = Color(0xFFCBD2D9);
  static const lockedShadow = Color(0xFF9AA5B1);
  static const ink = Color(0xFF3C3C3C);
  static const streakShadow = Color(0xFFCC8B00);
  static const line = Color(0xFFE5E5E5);
  static const tint = Color(0xFFDDF4FF);
}

/// Spacing / radius scale used across the app.
class AppSpace {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24;
}

class AppRadius {
  static const double sm = 12, md = 16, lg = 24;
}

ThemeData buildTheme() {
  const base = TextStyle(fontFamily: 'Nunito', color: Color(0xFF1F2933));
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Nunito',
    splashFactory: NoSplash.splashFactory,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
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
BoxDecoration duoCard({Color border = AppColors.locked, Color? fill, Color? shadow, double radius = 16}) => BoxDecoration(
      color: fill ?? Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border, width: 2),
      boxShadow: [BoxShadow(color: shadow ?? border, offset: const Offset(0, 4))],
    );
