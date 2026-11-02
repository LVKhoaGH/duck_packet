import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'i18n.dart';

class SettingsState {
  final bool sound, haptics;
  final String lang; // en | vi
  const SettingsState({this.sound = true, this.haptics = true, this.lang = 'en'});
  SettingsState copy({bool? sound, bool? haptics, String? lang}) =>
      SettingsState(sound: sound ?? this.sound, haptics: haptics ?? this.haptics, lang: lang ?? this.lang);
}

/// Keys in the 'stats' Hive box: x_sound, x_haptics, x_lang.
/// Sfx reads x_sound / x_haptics straight from Hive, so keep the key names.
class SettingsNotifier extends Notifier<SettingsState> {
  Box get _box => Hive.box('stats');

  @override
  SettingsState build() {
    final lang = '${_box.get('x_lang', defaultValue: 'en')}' == 'vi' ? 'vi' : 'en';
    AppLang.code = lang;
    return SettingsState(
      sound: _box.get('x_sound', defaultValue: true) != false,
      haptics: _box.get('x_haptics', defaultValue: true) != false,
      lang: lang,
    );
  }

  void setSound(bool v) {
    _box.put('x_sound', v);
    state = state.copy(sound: v);
  }

  void setHaptics(bool v) {
    _box.put('x_haptics', v);
    state = state.copy(haptics: v);
  }

  void setLang(String l) {
    AppLang.code = l;
    _box.put('x_lang', l);
    state = state.copy(lang: l);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
