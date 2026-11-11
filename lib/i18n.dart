import 'package:flutter/material.dart' as m;
import 'package:flutter/widgets.dart' hide Text;
import 'i18n_vi.dart';
import 'i18n_vi_meta.dart';

/// Current UI language ("en" or "vi"). Set by the settings notifier.
class AppLang {
  static String code = 'en';
  static bool get vi => code == 'vi';
}

/// Sits above the whole app. Widgets that depend on it rebuild when the language changes.
class LangScope extends InheritedWidget {
  final String code;
  const LangScope({super.key, required this.code, required super.child});
  @override
  bool updateShouldNotify(LangScope old) => old.code != code;
}

/// Call at the top of build() when using tr() directly (not through Text).
void watchLang(BuildContext c) => c.dependOnInheritedWidgetOfExactType<LangScope>();

/// Translate an English UI string. Unknown strings (course content, ids...) pass through unchanged.
String tr(String s) {
  if (!AppLang.vi) return s;
  final d = kVi[s] ?? kViMeta[s];
  if (d != null) return d;
  for (final r in [...kViRules, ...kViMetaRules]) {
    final mt = r.re.firstMatch(s);
    if (mt != null) return r.build(mt);
  }
  return s;
}

/// Drop-in replacement for Flutter's Text that translates its string.
/// Files use:  import 'package:flutter/material.dart' hide Text;  +  import 'i18n.dart';
class Text extends StatelessWidget {
  final String? data;
  final InlineSpan? span;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const Text(String this.data, {super.key, this.style, this.textAlign, this.maxLines, this.overflow}) : span = null;
  const Text.rich(InlineSpan this.span, {super.key, this.style, this.textAlign, this.maxLines, this.overflow}) : data = null;

  @override
  Widget build(BuildContext context) {
    watchLang(context);
    if (data != null) {
      return m.Text(tr(data!), style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
    }
    return m.Text.rich(span!, style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
  }
}
