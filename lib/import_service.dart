import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'library.dart';

class ImportReport {
  final List<String> ok = [];
  final List<String> failed = [];
}

class ImportService {
  final Ref ref;
  ImportService(this.ref);

  /// Pick one or many .json / .zip files. Every JSON becomes one pack.
  /// Returns null if cancelled. A bad file is reported but does not stop the others.
  Future<ImportReport?> importFiles({String folder = ''}) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'zip'],
      allowMultiple: true,
      withData: true,
    );
    if (res == null) return null;
    final rep = ImportReport();
    for (final f in res.files) {
      final bytes = f.bytes;
      if (bytes == null) {
        rep.failed.add('${f.name}: could not read the file');
        continue;
      }
      if (f.extension?.toLowerCase() == 'zip') {
        try {
          var any = false;
          for (final e in ZipDecoder().decodeBytes(bytes).files) {
            if (e.isFile && e.name.toLowerCase().endsWith('.json')) {
              any = true;
              _addOne(rep, e.name.split('/').last, e.content as List<int>, folder);
            }
          }
          if (!any) rep.failed.add('${f.name}: no .json file inside the zip');
        } catch (e) {
          rep.failed.add('${f.name}: not a valid zip');
        }
      } else {
        _addOne(rep, f.name, bytes, folder);
      }
    }
    return rep;
  }

  void _addOne(ImportReport rep, String fileName, List<int> bytes, String folder) {
    final name = fileName.replaceAll(RegExp(r'\.json$', caseSensitive: false), '');
    try {
      var text = utf8.decode(bytes, allowMalformed: true);
      if (text.startsWith('\uFEFF')) text = text.substring(1); // BOM from Windows editors
      final j = jsonDecode(text);
      if (j is! Map) {
        rep.failed.add('$fileName: the top level must be an object { ... }');
        return;
      }
      final err = ref.read(packsProvider.notifier).add(name, Map<String, dynamic>.from(j), folder: folder);
      if (err == null) {
        rep.ok.add(fileName);
      } else {
        rep.failed.add('$fileName:\n$err');
      }
    } on FormatException catch (e) {
      rep.failed.add('$fileName: invalid JSON (${e.message})');
    } catch (e) {
      rep.failed.add('$fileName: $e');
    }
  }
}

final importServiceProvider = Provider((ref) => ImportService(ref));
