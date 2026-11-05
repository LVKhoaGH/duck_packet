import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';

/// One imported JSON file. Several packs are merged into the course you play.
class Pack {
  final String id, name;
  final bool enabled;
  final Map<String, dynamic> data;

  /// Id of the folder this file sits in; '' = not in a folder. Stored by the app, never inside the user's JSON.
  final String folder;
  Pack({required this.id, required this.name, required this.enabled, required this.data, this.folder = ''});

  late final Course course = Course.fromJson(data);

  Pack copy({bool? enabled, String? folder}) =>
      Pack(id: id, name: name, enabled: enabled ?? this.enabled, data: data, folder: folder ?? this.folder);

  int get nodeCount => course.chapters.fold(0, (a, c) => a + c.nodes.length);
  int get questionCount => course.allNodes.fold(0, (a, n) => a + n.questions.length);
  int get lessonCount => course.allNodes.where((n) => n.lesson.isNotEmpty).length;
  Set<String> get chapterIds => course.chapters.map((c) => c.id).toSet();
  Set<String> get nodeIds => course.allNodes.map((n) => n.id).toSet();

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'enabled': enabled, 'folder': folder, 'data': data};
  factory Pack.fromJson(Map<String, dynamic> j) => Pack(
        id: '${j['id']}',
        name: '${j['name']}',
        enabled: j['enabled'] != false,
        folder: '${j['folder'] ?? ''}',
        data: Map<String, dynamic>.from(j['data'] as Map),
      );
}

/// The list of imported files. Stored in Hive box 'course', key 'packs'.
class PackNotifier extends Notifier<List<Pack>> {
  Box get _box => Hive.box('course');

  void _persist(List<Pack> l) => _box.put('packs', jsonEncode(l.map((p) => p.toJson()).toList()));

  @override
  List<Pack> build() {
    final out = <Pack>[];
    final raw = _box.get('packs');
    if (raw is String && raw.isNotEmpty) {
      try {
        for (final e in jsonDecode(raw) as List) {
          try {
            final p = Pack.fromJson(Map<String, dynamic>.from(e as Map));
            p.course; // parse now so a corrupt pack is skipped instead of crashing later
            out.add(p);
          } catch (_) {}
        }
      } catch (_) {}
      return out;
    }
    // Migrate the single course saved by older versions ('active').
    final old = _box.get('active');
    if (old is String && old.isNotEmpty) {
      try {
        final p = Pack(id: 'legacy', name: 'Imported course', enabled: true, data: Map<String, dynamic>.from(jsonDecode(old) as Map));
        p.course;
        out.add(p);
        _persist(out);
        _box.delete('active');
      } catch (_) {}
    }
    return out;
  }

  /// Adds a file (or replaces the pack with the same name). Returns an error text, or null on success.
  String? add(String name, Map<String, dynamic> data, {String folder = ''}) {
    final errs = validatePack(data);
    if (errs.isNotEmpty) {
      return errs.take(8).join('\n') + (errs.length > 8 ? '\n... and ${errs.length - 8} more' : '');
    }
    final at = state.indexWhere((p) => p.name == name);
    final pack = Pack(
      id: at >= 0 ? state[at].id : DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      enabled: at >= 0 ? state[at].enabled : true,
      data: data,
      folder: at >= 0 ? state[at].folder : folder,
    );
    final usedCh = <String>{}, usedNodes = <String>{};
    for (var i = 0; i < state.length; i++) {
      if (i == at) continue;
      usedCh.addAll(state[i].chapterIds);
      usedNodes.addAll(state[i].nodeIds);
    }
    final dup = <String>[
      for (final c in pack.chapterIds) if (usedCh.contains(c)) 'chapter_id "$c"',
      for (final n in pack.nodeIds) if (usedNodes.contains(n)) 'node_id "$n"',
    ];
    if (dup.isNotEmpty) {
      return 'IDs already used by another file: ${dup.take(6).join(', ')}${dup.length > 6 ? ', ...' : ''}\nGive them unique ids, or remove the other file first.';
    }
    final l = [...state];
    if (at >= 0) {
      l[at] = pack;
    } else {
      l.add(pack);
    }
    state = l;
    _persist(l);
    return null;
  }

  void toggle(String id) {
    state = [for (final p in state) p.id == id ? p.copy(enabled: !p.enabled) : p];
    _persist(state);
  }

  void remove(String id) {
    state = state.where((p) => p.id != id).toList();
    _persist(state);
  }

  /// Moves a file up/down among the files of the same folder.
  void move(String id, int delta) {
    final i = state.indexWhere((p) => p.id == id);
    if (i < 0) return;
    final same = <int>[for (var k = 0; k < state.length; k++) if (state[k].folder == state[i].folder) k];
    final pos = same.indexOf(i);
    final to = pos + delta;
    if (to < 0 || to >= same.length) return;
    final l = [...state];
    final a = same[pos], b = same[to];
    final t = l[a];
    l[a] = l[b];
    l[b] = t;
    state = l;
    _persist(l);
  }

  /// Puts a file into a folder ('' = take it out of any folder). It goes to the end of that folder.
  void moveTo(String id, String folder) {
    final i = state.indexWhere((p) => p.id == id);
    if (i < 0 || state[i].folder == folder) return;
    final l = [...state];
    final p = l.removeAt(i).copy(folder: folder);
    l.add(p);
    state = l;
    _persist(l);
  }

  void setEnabledIn(String folder, bool on) {
    state = [for (final p in state) p.folder == folder && p.enabled != on ? p.copy(enabled: on) : p];
    _persist(state);
  }

  void removeIn(String folder) {
    state = state.where((p) => p.folder != folder).toList();
    _persist(state);
  }

  /// Takes every file out of the folder (used when a folder is deleted but its files are kept).
  void ungroup(String folder) {
    state = [for (final p in state) p.folder == folder ? p.copy(folder: '') : p];
    _persist(state);
  }
}

final packsProvider = NotifierProvider<PackNotifier, List<Pack>>(PackNotifier.new);

// ───────────────────────── folders ─────────────────────────
/// A folder that groups several imported files. Purely organisational; the JSON files are untouched.
class PackFolder {
  final String id, name;
  final bool open;
  const PackFolder({required this.id, required this.name, this.open = true});

  PackFolder copy({String? name, bool? open}) => PackFolder(id: id, name: name ?? this.name, open: open ?? this.open);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'open': open};
  factory PackFolder.fromJson(Map<String, dynamic> j) => PackFolder(id: '${j['id']}', name: '${j['name']}', open: j['open'] != false);
}

/// Folder list, stored in Hive box 'course', key 'folders'.
class FolderNotifier extends Notifier<List<PackFolder>> {
  Box get _box => Hive.box('course');

  void _persist(List<PackFolder> l) => _box.put('folders', jsonEncode(l.map((f) => f.toJson()).toList()));

  @override
  List<PackFolder> build() {
    final out = <PackFolder>[];
    final raw = _box.get('folders');
    if (raw is String && raw.isNotEmpty) {
      try {
        for (final e in jsonDecode(raw) as List) {
          try {
            out.add(PackFolder.fromJson(Map<String, dynamic>.from(e as Map)));
          } catch (_) {}
        }
      } catch (_) {}
    }
    return out;
  }

  String create(String name) {
    final id = 'f${DateTime.now().microsecondsSinceEpoch}';
    state = [...state, PackFolder(id: id, name: name)];
    _persist(state);
    return id;
  }

  void rename(String id, String name) {
    state = [for (final f in state) f.id == id ? f.copy(name: name) : f];
    _persist(state);
  }

  void toggleOpen(String id) {
    state = [for (final f in state) f.id == id ? f.copy(open: !f.open) : f];
    _persist(state);
  }

  void remove(String id) {
    state = state.where((f) => f.id != id).toList();
    _persist(state);
  }

  void move(String id, int delta) {
    final i = state.indexWhere((f) => f.id == id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= state.length) return;
    final l = [...state];
    final f = l.removeAt(i);
    l.insert(j, f);
    state = l;
    _persist(l);
  }
}

final foldersProvider = NotifierProvider<FolderNotifier, List<PackFolder>>(FolderNotifier.new);

/// Display / play order: folders top to bottom (files in list order inside each), then files not in a folder.
List<Pack> orderedPacks(List<Pack> packs, List<PackFolder> folders) {
  final ids = {for (final f in folders) f.id};
  final out = <Pack>[];
  for (final f in folders) {
    out.addAll(packs.where((p) => p.folder == f.id));
  }
  out.addAll(packs.where((p) => !ids.contains(p.folder)));
  return out;
}

/// Chapters of all enabled packs, in list order. Null when nothing is enabled (the app is "empty").
Course? mergeCourse(List<Pack> packs, [List<PackFolder> folders = const []]) {
  final on = orderedPacks(packs, folders).where((p) => p.enabled).toList();
  if (on.isEmpty) return null;
  final seen = <String>{};
  final gl = <GlossaryItem>[];
  for (final p in on) {
    for (final g in p.course.glossary) {
      if (seen.add(g.term.toLowerCase())) gl.add(g);
    }
  }
  final first = on.first.course;
  return Course(id: first.id, title: first.title, chapters: [for (final p in on) ...p.course.chapters], glossary: gl);
}

/// Same type the rest of the app already uses (`.when`, `.valueOrNull`).
final courseProvider =
    Provider<AsyncValue<Course?>>((ref) => AsyncData(mergeCourse(ref.watch(packsProvider), ref.watch(foldersProvider))));

// ───────────────────────── validation ─────────────────────────
String _s(dynamic v) => v == null ? '' : '$v';
List _l(dynamic v) => v is List ? v : const [];

/// Returns human-readable problems; empty list = file is OK to import.
List<String> validatePack(Map<String, dynamic> j) {
  final e = <String>[];
  final chs = j['chapters'];
  if (chs != null && chs is! List) e.add('"chapters" must be a list');
  if (chs == null && j['glossary'] == null) e.add('File needs "chapters" (and/or "glossary")');
  final chIds = <String>{}, nodeIds = <String>{};
  if (chs is List) {
    for (var ci = 0; ci < chs.length; ci++) {
      final ch = chs[ci];
      if (ch is! Map) {
        e.add('chapters[$ci] is not an object');
        continue;
      }
      final cid = _s(ch['chapter_id']).trim();
      if (cid.isEmpty) {
        e.add('chapters[$ci]: missing chapter_id');
      } else if (!chIds.add(cid)) {
        e.add('Duplicate chapter_id "$cid"');
      }
      if (_s(ch['chapter_title']).trim().isEmpty) e.add('chapter "$cid": missing chapter_title');
      final nodes = ch['nodes'];
      if (nodes is! List) {
        e.add('chapter "$cid": "nodes" must be a list');
        continue;
      }
      for (var ni = 0; ni < nodes.length; ni++) {
        final n = nodes[ni];
        if (n is! Map) {
          e.add('chapter "$cid" nodes[$ni] is not an object');
          continue;
        }
        final nid = _s(n['node_id']).trim();
        if (nid.isEmpty) {
          e.add('chapter "$cid" nodes[$ni]: missing node_id');
        } else if (!nodeIds.add(nid)) {
          e.add('Duplicate node_id "$nid"');
        }
        if (_s(n['node_title']).trim().isEmpty) e.add('node "$nid": missing node_title');
        final qs = n['questions'];
        if (qs is! List) {
          e.add('node "$nid": "questions" must be a list');
        } else {
          for (var qi = 0; qi < qs.length; qi++) {
            _checkQuestion(e, '$nid question ${qi + 1}', qs[qi]);
          }
        }
        final lesson = n['lesson'];
        if (lesson != null) {
          if (lesson is! List) {
            e.add('node "$nid": "lesson" must be a list of cards');
          } else {
            for (var li = 0; li < lesson.length; li++) {
              if (lesson[li] is! Map) e.add('node "$nid" lesson card ${li + 1}: not an object');
            }
          }
        }
      }
    }
  }
  final gl = j['glossary'];
  if (gl != null) {
    if (gl is! List) {
      e.add('"glossary" must be a list');
    } else {
      for (var gi = 0; gi < gl.length; gi++) {
        final g = gl[gi];
        if (g is! Map || _s(g['term']).trim().isEmpty || _s(g['def']).trim().isEmpty) {
          e.add('glossary item ${gi + 1}: needs "term" and "def"');
        }
      }
    }
  }
  return e;
}

void _checkQuestion(List<String> e, String at, dynamic q) {
  if (q is! Map) {
    e.add('$at: not an object');
    return;
  }
  final type = _s(q['type']);
  if (_s(q['prompt']).trim().isEmpty) e.add('$at: empty prompt');
  final options = _l(q['options']).map((x) => '$x').toList();
  final answer = _s(q['correct_answer']);
  final pairs = _l(q['pairs']);
  final pairsOk = pairs.every((p) => p is Map && _s(p['left']).trim().isNotEmpty && _s(p['right']).trim().isNotEmpty);

  if (type == 'reorder') {
    final items = _l(q['items']);
    final order = _l(q['correct_order']);
    if (items.length < 2) e.add('$at: reorder needs at least 2 items');
    final okOrder = order.length == items.length &&
        order.every((x) => x is int && x >= 0 && x < items.length) &&
        order.toSet().length == order.length;
    if (!okOrder) e.add('$at: correct_order must list every index 0..${items.length - 1} exactly once');
  } else if (type == 'match_pairs') {
    if (pairs.length < 2 || !pairsOk) {
      e.add('$at: match_pairs needs 2+ pairs, each with "left" and "right"');
    } else {
      final rights = pairs.map((p) => _s(p['right'])).toList();
      if (rights.toSet().length != rights.length) e.add('$at: match_pairs "right" values must all be different');
    }
  } else if (type == 'fill_code') {
    final n = '[BLANK]'.allMatches(_s(q['template'])).length;
    if (n != 1) e.add('$at: template must contain [BLANK] exactly once (found $n)');
    if (!options.contains(answer)) e.add('$at: correct_answer "$answer" is not in options');
  } else if (type == 'multiple_choice') {
    if (options.length < 2) e.add('$at: multiple_choice needs 2+ options');
    if (!options.contains(answer)) e.add('$at: correct_answer "$answer" is not in options');
  } else if (type == 'categorize') {
    if (pairs.length < 2 || !pairsOk) {
      e.add('$at: categorize needs 2+ pairs, each with "left" (term) and "right" (group name)');
    } else {
      final groups = pairs.map((p) => _s(p['right'])).toSet();
      if (groups.length < 2) e.add('$at: categorize needs at least 2 different groups');
      final lefts = pairs.map((p) => _s(p['left'])).toList();
      if (lefts.toSet().length != lefts.length) e.add('$at: categorize "left" terms must all be different');
    }
  } else {
    e.add('$at: unknown type "$type" (use reorder, match_pairs, fill_code, multiple_choice, categorize)');
  }
}
