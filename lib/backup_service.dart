import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'backup_io_stub.dart' if (dart.library.io) 'backup_io_native.dart';
import 'extras.dart';
import 'library.dart';
import 'providers.dart';
import 'study.dart';

/// Export / restore all progress (+ the imported course) as one JSON file.
class BackupService {
  final Ref ref;
  BackupService(this.ref);

  String _build() => jsonEncode({
        'app': 'duckpacket',
        'v': 1,
        'saved': DateTime.now().toIso8601String(),
        'stats': Map<String, dynamic>.from(Hive.box('stats').toMap().map((k, v) => MapEntry('$k', v))),
        'packs': Hive.box('course').get('packs'),
        'folders': Hive.box('course').get('folders'),
      });

  /// Returns a short message for the user, or null if cancelled.
  Future<String?> export() async {
    final text = _build();
    final data = Uint8List.fromList(utf8.encode(text));
    final name = 'duckpacket_backup_${dayKey(DateTime.now())}.json';
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save backup',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: data,
      );
      if (path == null) return null;
      await writeBackupFile(path, data);
      return 'Backup saved: $name';
    } catch (_) {
      // Fallback that always works: put the JSON on the clipboard.
      await Clipboard.setData(ClipboardData(text: text));
      return 'Could not save a file. Backup JSON copied to clipboard instead.';
    }
  }

  /// Returns a message, or null if cancelled. Throws on an invalid file.
  Future<String?> restore() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (res == null || res.files.single.bytes == null) return null;
    final m = jsonDecode(utf8.decode(res.files.single.bytes!)) as Map<String, dynamic>;
    if (m['app'] != 'duckpacket' || m['stats'] is! Map) {
      throw const FormatException('This is not a DuckPacket backup');
    }
    final box = Hive.box('stats');
    await box.clear();
    for (final e in (m['stats'] as Map).entries) {
      await box.put('${e.key}', e.value);
    }
    final cbox = Hive.box('course');
    if (m['packs'] is String) {
      await cbox.put('packs', m['packs']);
      await cbox.delete('active');
    } else if (m['course'] is String) {
      // backup made by an older version: single course
      await cbox.delete('packs');
      await cbox.put('active', m['course']);
    }

    if (m['folders'] is String) {
      await cbox.put('folders', m['folders']);
    } else {
      await cbox.delete('folders');
    }

    ref.invalidate(statsProvider);
    ref.invalidate(extrasProvider);
    ref.invalidate(studyProvider);
    ref.invalidate(packsProvider);
    ref.invalidate(foldersProvider);
    return 'Progress restored';
  }
}

final backupServiceProvider = Provider((ref) => BackupService(ref));
