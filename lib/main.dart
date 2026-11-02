import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'home_screen.dart';
import 'i18n.dart';
import 'settings.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('stats');
  await Hive.openBox('course');
  runApp(const ProviderScope(child: DuckPacketApp()));
}

class DuckPacketApp extends StatelessWidget {
  const DuckPacketApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'DuckPacket',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomeScreen(),
        // Language scope on top of everything, then (on wide screens) a 9:20 phone frame.
        builder: (context, child) => Consumer(
          builder: (context, ref, _) => LangScope(
            code: ref.watch(settingsProvider).lang,
            child: LayoutBuilder(builder: (context, c) {
              if (c.maxWidth <= 600) return child!;
              final w = (c.maxHeight * 9 / 20).clamp(360.0, 430.0);
              final h = c.maxHeight < w * 20 / 9 ? c.maxHeight : w * 20 / 9;
              return Container(
                color: const Color(0xFF0F1720),
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(size: Size(w, h)),
                      child: child!,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      );
}
