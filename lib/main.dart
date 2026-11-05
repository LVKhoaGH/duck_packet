import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'duck.dart';
import 'home_screen.dart';
import 'i18n.dart';
import 'settings.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('stats');
  await Hive.openBox('course');
  await DuckArt.load(); // the duck is drawn from PNG layers; load them before the first frame
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
        // Language scope on top of everything. Window size decides the layout:
        //   < 600 px  phone, full screen (portrait)
        //   600-800   tablet portrait: phone layout, centred, max 560 px
        //   >= 800    laptop / landscape: HomeScreen switches to a side navigation rail, content max 1180 px
        builder: (context, child) => Consumer(
          builder: (context, ref, _) => LangScope(
            code: ref.watch(settingsProvider).lang,
            child: LayoutBuilder(builder: (context, c) {
              if (c.maxWidth < 600) return child!;
              final maxW = c.maxWidth < 800 ? 560.0 : 1180.0;
              final w = c.maxWidth < maxW ? c.maxWidth : maxW;
              return Container(
                color: const Color(0xFFE9EDF1),
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
          ),
        ),
      );
}
