import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';

/// Boss is defeated at this accuracy (%) or higher.
const kBossPass = 80;

/// Spaced repetition steps (days): wrong -> due in 1 day, then 3, then 7, then graduated.
const kSrsDays = [1, 3, 7];

const kDomainNames = {
  1: 'Architecture',
  2: 'Virtualization',
  3: 'Infrastructure',
  4: 'Network Assurance',
  5: 'Security',
  6: 'Automation & AI',
};

/// Day number of the local calendar date.
int dayNum([DateTime? t]) {
  final n = t ?? DateTime.now();
  return DateTime.utc(n.year, n.month, n.day).millisecondsSinceEpoch ~/ 86400000;
}

/// Stable id of a question (derived from type + prompt, so it survives re-importing the course).
String qidOf(Question q) {
  var h1 = 7, h2 = 11;
  final s = '${q.type}|${q.prompt}';
  for (final c in s.codeUnits) {
    h1 = (h1 * 31 + c) & 0x3FFFFFF;
    h2 = (h2 * 131 + c) & 0x3FFFFFF;
  }
  return '${h1.toRadixString(36)}${h2.toRadixString(36)}${s.length}';
}

// ───────────────────────── per-question record ─────────────────────────
class QRec {
  int a, c, box, due, last;
  bool wrong, lastOk, enrolled;
  QRec({this.a = 0, this.c = 0, this.box = 0, this.due = 0, this.last = 0, this.wrong = false, this.lastOk = false, this.enrolled = false});

  List<int> toJson() => [a, c, box, due, last, wrong ? 1 : 0, lastOk ? 1 : 0, enrolled ? 1 : 0];
  factory QRec.fromJson(List l) => QRec(
        a: l[0] as int,
        c: l[1] as int,
        box: l[2] as int,
        due: l[3] as int,
        last: l[4] as int,
        wrong: l[5] == 1,
        lastOk: l[6] == 1,
        enrolled: l[7] == 1,
      );
}

class StudyState {
  final Map<String, QRec> recs;
  final Map<String, int> best; // node/boss id -> best accuracy %
  final Set<String> seen; // node ids whose lesson was read to the end
  const StudyState({this.recs = const {}, this.best = const {}, this.seen = const {}});
}

/// Mistakes, spaced repetition, best scores, lesson progress.
/// Keys in the 'stats' Hive box: x_study, x_best, x_seen.
class StudyNotifier extends Notifier<StudyState> {
  Box get _box => Hive.box('stats');

  @override
  StudyState build() {
    final recs = <String, QRec>{};
    final best = <String, int>{};
    try {
      final raw = _box.get('x_study');
      if (raw is String && raw.isNotEmpty) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) => recs[k] = QRec.fromJson(v as List));
      }
    } catch (_) {}
    try {
      final raw = _box.get('x_best');
      if (raw is String && raw.isNotEmpty) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) => best[k] = (v as num).toInt());
      }
    } catch (_) {}
    final seen = ((_box.get('x_seen') as List?) ?? const []).map((e) => '$e').toSet();
    return StudyState(recs: recs, best: best, seen: seen);
  }

  void _save() {
    _box.put('x_study', jsonEncode(state.recs.map((k, v) => MapEntry(k, v.toJson()))));
    _box.put('x_best', jsonEncode(state.best));
    _box.put('x_seen', state.seen.toList());
  }

  /// Record the FIRST attempt of a question in a session. Retries of the same question are ignored.
  void record(String id, bool ok, {bool retry = false}) {
    if (retry) return;
    final recs = Map<String, QRec>.from(state.recs);
    final r = recs[id] ?? QRec();
    final today = dayNum();
    r.a++;
    if (ok) r.c++;
    r.lastOk = ok;
    r.last = today;
    if (!ok) {
      r.wrong = true;
      r.enrolled = true;
      r.box = 0;
      r.due = today + kSrsDays[0];
    } else {
      r.wrong = false;
      if (r.enrolled && r.due <= today) {
        r.box++;
        if (r.box >= kSrsDays.length) {
          r.enrolled = false; // graduated
        } else {
          r.due = today + kSrsDays[r.box];
        }
      }
    }
    recs[id] = r;
    state = StudyState(recs: recs, best: state.best, seen: state.seen);
    _save();
  }

  void setBest(String id, int acc) {
    if ((state.best[id] ?? -1) >= acc) return;
    state = StudyState(recs: state.recs, best: {...state.best, id: acc}, seen: state.seen);
    _save();
  }

  void markSeen(String nodeId) {
    if (state.seen.contains(nodeId)) return;
    state = StudyState(recs: state.recs, best: state.best, seen: {...state.seen, nodeId});
    _save();
  }

  void reset() {
    for (final k in ['x_study', 'x_best', 'x_seen']) {
      _box.delete(k);
    }
    state = const StudyState();
  }
}

final studyProvider = NotifierProvider<StudyNotifier, StudyState>(StudyNotifier.new);

// ───────────────────────── course helpers ─────────────────────────
class QRef {
  final Question q;
  final CourseNode node;
  final Chapter chapter;
  QRef(this.q, this.node, this.chapter);
}

Map<String, QRef> indexCourse(Course c) {
  final m = <String, QRef>{};
  for (final ch in c.chapters) {
    for (final n in ch.nodes) {
      for (final q in n.questions) {
        m[qidOf(q)] = QRef(q, n, ch);
      }
    }
  }
  return m;
}

String bossId(Chapter ch) => 'boss:${ch.id}';

/// Linear order of everything to beat: node, node, ..., boss, node, ..., boss.
List<String> stageIds(Course c) => [
      for (final ch in c.chapters)
        if (ch.nodes.isNotEmpty) ...[for (final n in ch.nodes) n.id, bossId(ch)],
    ];

/// First stage of EVERY chapter is open; inside a chapter you go in order (node, node, ..., boss).
bool stageUnlocked(Course c, Set<String> done, String id) {
  for (final ch in c.chapters) {
    final seq = [for (final n in ch.nodes) n.id, bossId(ch)];
    final i = seq.indexOf(id);
    if (i < 0) continue;
    return i == 0 || done.contains(seq[i - 1]);
  }
  return true;
}

class DomainStat {
  final String label;
  final int order;
  final List<Question> qs = [];
  DomainStat(this.label, this.order);

  String get title => order < 99 ? '$order · $label' : label;
  double mastery(Map<String, QRec> r) =>
      qs.isEmpty ? 0 : qs.where((q) => r[qidOf(q)]?.lastOk == true).length / qs.length;
  int attempted(Map<String, QRec> r) => qs.where((q) => (r[qidOf(q)]?.a ?? 0) > 0).length;
}

/// Groups chapters by exam domain (number before ".0" in the chapter title, e.g. "3.0 Infrastructure").
/// Chapters without such a number become their own group.
List<DomainStat> domainStats(Course c) {
  final groups = <String, DomainStat>{};
  final re = RegExp(r'\b([1-6])\.0\b');
  for (final ch in c.chapters) {
    final m = re.firstMatch(ch.title);
    final order = m != null ? int.parse(m.group(1)!) : 99;
    final key = m != null ? 'd$order' : 'c:${ch.title}';
    final label = m != null ? (kDomainNames[order] ?? ch.title) : ch.title;
    final g = groups.putIfAbsent(key, () => DomainStat(label, order));
    for (final n in ch.nodes) {
      g.qs.addAll(n.questions);
    }
  }
  final l = groups.values.where((g) => g.qs.isNotEmpty).toList()..sort((a, b) => a.order.compareTo(b.order));
  return l;
}
