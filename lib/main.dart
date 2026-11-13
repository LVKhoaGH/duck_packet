import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'duck.dart';
import 'home_screen.dart';
import 'i18n.dart';
import 'settings.dart';
import 'theme.dart';
import 'tracks.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('stats');
  await Hive.openBox('course');
  await DuckArt.load(); // the duck is drawn from PNG layers; load them before the first frame
  await Bundled.load(); // courses shipped inside the app (assets/courses/...)
  runApp(ProviderScope(overrides: [courseOverride()], child: const DuckPacketApp()));
}

class DuckPacketApp extends ConsumerWidget {
  const DuckPacketApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        title: 'DuckPacket',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        darkTheme: buildTheme(dark: true),
        themeMode: switch (ref.watch(settingsProvider).theme) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        home: const _Root(),
        // Language scope on top of everything. Window size decides the layout:
        //   < 600 px  phone, full screen (portrait)
        //   600-800   tablet portrait: phone layout, centred, max 560 px
        //   >= 800    laptop / landscape: HomeScreen switches to a side navigation rail, content max 1180 px
        builder: (context, child) => Consumer(
          builder: (context, ref, _) {
            // Neutral colours (AppColors.ink, surface, ...) follow this flag. It must be set before the UI below is built.
            final mode = ref.watch(settingsProvider).theme;
            final sysDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
            final dark = mode == 'dark' || (mode == 'auto' && sysDark);
            if (dark != AppColors.dark) {
              AppColors.dark = dark;
              WidgetsBinding.instance.addPostFrameCallback((_) => rebuildAllElements());
            }
            return LangScope(
            code: ref.watch(settingsProvider).lang,
            child: LayoutBuilder(builder: (context, c) {
              if (c.maxWidth < 600) return child!;
              final maxW = c.maxWidth < 800 ? 560.0 : 1180.0;
              final w = c.maxWidth < maxW ? c.maxWidth : maxW;
              return Container(
                color: AppColors.outer,
                alignment: Alignment.center,
                child: SizedBox(
                  width: w,
                  height: c.maxHeight,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(size: Size(w, c.maxHeight)),
                    child: child!,
                  ),
                ),
              );
            }),
            );
          },
        ),
      );
}

/// First launch: pick a course. After that: the app. Changing course rebuilds HomeScreen from scratch (key = course id).
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trackProvider);
    if (t.isEmpty) return const TrackPickerScreen(first: true);
    if (t != kTrackCustom && Bundled.byTrack[t] == null) return const NoContentScreen();
    return KeyedSubtree(key: ValueKey(t), child: const HomeScreen());
  }
}
