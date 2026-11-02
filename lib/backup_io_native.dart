import 'dart:io';

/// Desktop: FilePicker.saveFile only returns a path, so write the file ourselves.
/// Android/iOS: the picker already wrote the bytes, nothing to do.
Future<void> writeBackupFile(String path, List<int> data) async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    final p = path.toLowerCase().endsWith('.json') ? path : '$path.json';
    await File(p).writeAsBytes(data);
  }
}
