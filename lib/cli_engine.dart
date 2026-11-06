// Cisco-IOS-style CLI simulator for lab questions. Pure Dart (no Flutter imports).
//
// Model: every device keeps its running-config as blocks of lines. Config commands
// add / replace / remove lines; "show" output is written by the lab author and can
// change with the config (variants). Grading looks at the FINAL config, not at the
// typed commands.
import 'cli_modules.dart';

// ───────────────────────── small helpers ─────────────────────────
bool _isParam(String t) => t.length > 2 && t.startsWith('<') && t.endsWith('>');

String _kind(String t) {
  final s = t.substring(1, t.length - 1);
  final i = s.indexOf(':');
  return i < 0 ? s : s.substring(0, i);
}

String _arg(String t) {
  final s = t.substring(1, t.length - 1);
  final i = s.indexOf(':');
  return i < 0 ? '' : s.substring(i + 1);
}

bool _isIp(String v) {
  final p = v.split('.');
  if (p.length != 4) return false;
  for (final x in p) {
    final n = int.tryParse(x);
    if (n == null || n < 0 || n > 255) return false;
  }
  return true;
}

const List<String> _ifTypes = [
  'GigabitEthernet',
  'FastEthernet',
  'TenGigabitEthernet',
  'Ethernet',
  'Loopback',
  'Vlan',
  'Port-channel',
  'Tunnel',
  'Serial',
];

/// "gi0/0" -> "GigabitEthernet0/0". Null when it is not an interface name.
String? expandIf(String v) {
  final m = RegExp(r'^([A-Za-z\-]+)(\d.*)$').firstMatch(v);
  if (m == null) return null;
  final t = m.group(1)!.toLowerCase();
  final rest = m.group(2)!;
  final hits = <String>[];
  for (final c in _ifTypes) {
    final lc = c.toLowerCase();
    if (lc == t) return c + rest;
    if (lc.startsWith(t)) hits.add(c);
  }
  if (hits.length == 1) return hits.first + rest;
  return null;
}

String normHead(String h) {
  final t = h.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.toLowerCase().startsWith('interface ')) {
    final n = expandIf(t.substring(10).trim());
    if (n != null) return 'interface $n';
  }
  return t;
}

String _norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
bool _eq(String a, String b) => _norm(a) == _norm(b);

/// true when [l] equals [p] or starts with [p] followed by a space.
bool _startsWord(String l, String p) {
  final a = _norm(l), b = _norm(p);
  return a == b || a.startsWith('$b ');
}

/// Case-insensitive match where "*" in [pat] matches anything.
bool labWild(String pat, String text) {
  final re = RegExp('^${_norm(pat).split('*').map(RegExp.escape).join('.*')}\$');
  return re.hasMatch(_norm(text));
}

String _text(dynamic o) {
  if (o == null) return '';
  if (o is List) return o.map((e) => '$e').join('\n');
  return '$o';
}

String? _param(String t, String v) {
  final k = _kind(t);
  if (k == 'num') {
    final n = int.tryParse(v);
    if (n == null) return null;
    final a = _arg(t);
    if (a.contains('-')) {
      final ps = a.split('-');
      final lo = int.tryParse(ps[0]);
      final hi = int.tryParse(ps[1]);
      if (lo != null && hi != null && (n < lo || n > hi)) return null;
    }
    return '$n';
  }
  if (k == 'ip' || k == 'mask' || k == 'wild') return _isIp(v) ? v : null;
  if (k == 'ifname') return expandIf(v);
  return v; // word, any, rest
}

String _paramHelp(String t) {
  final k = _kind(t);
  if (k == 'num') {
    final a = _arg(t);
    return a.isEmpty ? '<number>' : '<$a>';
  }
  if (k == 'ip' || k == 'mask' || k == 'wild') return 'A.B.C.D';
  if (k == 'ifname') return 'WORD (interface)';
  if (k == 'rest') return 'LINE';
  return 'WORD';
}

// ───────────────────────── data classes ─────────────────────────
class CfgBlock {
  String head;
  final List<String> lines;
  CfgBlock(this.head, [List<String>? l]) : lines = l ?? <String>[];
}

class ShowRule {
  final String def;
  final List<Map<String, dynamic>> variants;
  ShowRule(this.def, this.variants);
}

class CmdDef {
  final List<String> modes;
  final List<String> pat;
  final String enter, action, key;
  final bool replace, negStore;
  final ShowRule? show;
  CmdDef({
    required this.modes,
    required this.pat,
    this.enter = '',
    this.action = '',
    this.key = '',
    this.replace = false,
    this.negStore = false,
    this.show,
  });
}

const Set<String> _kinds = {'num', 'ip', 'mask', 'wild', 'word', 'any', 'ifname', 'rest'};

/// Parses "modes|pattern|flags". Null when the line is malformed.
CmdDef? parseDefLine(String line) {
  final parts = line.split('|');
  if (parts.length < 2) return null;
  final modes = parts[0].split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  final pat = parts[1].trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (modes.isEmpty || pat.isEmpty) return null;
  for (var i = 0; i < pat.length; i++) {
    final t = pat[i];
    if (t.startsWith('<') || t.endsWith('>')) {
      if (!_isParam(t) || !_kinds.contains(_kind(t))) return null;
      if (_kind(t) == 'rest' && i != pat.length - 1) return null;
    }
  }
  var replace = false, neg = false;
  var enter = '', action = '', key = '';
  if (parts.length > 2) {
    for (final f in parts[2].split(',')) {
      final x = f.trim();
      if (x == 'replace') {
        replace = true;
      } else if (x == 'neg') {
        neg = true;
      } else if (x.startsWith('enter=')) {
        enter = x.substring(6);
      } else if (x.startsWith('action=')) {
        action = x.substring(7);
      } else if (x.startsWith('key=')) {
        key = x.substring(4);
      }
    }
  }
  return CmdDef(
      modes: modes, pat: pat, enter: enter, action: action, key: key, replace: replace, negStore: neg);
}

/// A "grammar" entry of a lab: either the string form or {mode, pattern, replace, enter, neg, key}.
CmdDef? parseGrammarEntry(dynamic e) {
  if (e is String) return parseDefLine(e);
  if (e is Map) {
    final mode = e['mode'];
    final modes = mode is List ? mode.map((x) => '$x').join(',') : '${mode ?? 'config'}';
    final fl = <String>[];
    if (e['replace'] == true) fl.add('replace');
    if (e['neg'] == true) fl.add('neg');
    if (e['enter'] != null) fl.add('enter=${e['enter']}');
    if (e['key'] != null) fl.add('key=${e['key']}');
    return parseDefLine('$modes|${e['pattern'] ?? ''}|${fl.join(',')}');
  }
  return null;
}

class LabDev {
  final String id, kind;
  String hostname;
  String mode;
  String ctx = '';
  List<CfgBlock> cfg;
  List<CfgBlock> startup;
  bool saved = true;
  final List<String> log = [];
  final List<String> history = [];
  List<CmdDef> defs = [];
  LabDev(this.id, this.kind, this.hostname, this.mode, this.cfg, this.startup);
}

class _P {
  final CmdDef def;
  final List<String> exp;
  _P(this.def, this.exp);
}

class _Nar {
  List<_P> alive = [];
  String err = '';
  int tok = -1;
}

class _Res {
  _P? p;
  String err = '';
  int tok = -1;
}

List<CfgBlock> _clone(List<CfgBlock> l) => [for (final b in l) CfgBlock(b.head, List<String>.of(b.lines))];

List<CfgBlock> _parseCfg(List<String> raw) {
  final out = <CfgBlock>[];
  for (final r in raw) {
    final line = r.replaceAll('\t', '  ').trimRight();
    if (line.trim().isEmpty || line.trim() == '!') continue;
    if (line.startsWith(' ')) {
      if (out.isNotEmpty) out.last.lines.add(line.substring(1));
    } else {
      out.add(CfgBlock(normHead(line)));
    }
  }
  // "no shutdown" is not shown in a real running-config.
  for (final b in out) {
    b.lines.removeWhere((l) => _norm(l) == 'no shutdown');
  }
  return out;
}

bool _modeOk(CmdDef def, String mode) {
  for (final m in def.modes) {
    if (m == '*') return true;
    if (m.endsWith('*')) {
      if (mode.startsWith(m.substring(0, m.length - 1))) return true;
    } else if (m == mode) {
      return true;
    }
  }
  return false;
}

/// Text of the author's solution (for the red "Correct solution:" box).
String labSolutionText(Map<String, dynamic> lab) {
  final sol = lab['solution'];
  if (sol is! List) return '';
  final out = <String>[];
  for (final s in sol) {
    if (s is! Map) continue;
    out.add('${s['device']}:');
    final cmds = s['commands'];
    if (cmds is List) {
      for (final c in cmds) {
        out.add('  $c');
      }
    }
  }
  return out.join('\n');
}

// ───────────────────────── the session ─────────────────────────
class LabSession {
  final Map<String, dynamic> lab;
  final List<LabDev> devs = [];
  int cur = 0;
  bool touched = false;
  int hintsUsed = 0;

  LabSession(this.lab) {
    _build();
  }

  LabDev get dev => devs[cur];
  bool get allowHelp => lab['allow_help'] != false;
  String get scenario => '${lab['scenario'] ?? ''}';

  List<Map<String, String>> get tasks {
    final out = <Map<String, String>>[];
    final t = lab['tasks'];
    if (t is List) {
      for (var i = 0; i < t.length; i++) {
        final x = t[i];
        if (x is Map) {
          out.add({'id': '${x['id'] ?? 't$i'}', 'text': '${x['text'] ?? ''}'});
        } else {
          out.add({'id': 't$i', 'text': '$x'});
        }
      }
    }
    return out;
  }

  List<String> get hints {
    final h = lab['hints'];
    return h is List ? h.map((e) => '$e').toList() : <String>[];
  }

  int get maxHints {
    final m = lab['max_hints'];
    final n = m is int ? m : hints.length;
    return n < hints.length ? n : hints.length;
  }

  String? nextHint() {
    if (hintsUsed >= maxHints) return null;
    final h = hints[hintsUsed];
    hintsUsed++;
    return h;
  }

  List<String> topologyLines() {
    final t = lab['topology'];
    if (t is String) return t.split('\n');
    final out = <String>[];
    if (t is Map && t['links'] is List) {
      String end(String s, bool left) {
        final p = s.split(':');
        if (p.length < 2) return s;
        return left ? '${p[0]} (${p[1]})' : '(${p[1]}) ${p[0]}';
      }

      for (final l in t['links'] as List) {
        if (l is! Map) continue;
        final lbl = '${l['label'] ?? ''}';
        out.add('${end('${l['a']}', true)} ──── ${end('${l['b']}', false)}${lbl.isEmpty ? '' : '   $lbl'}');
      }
    }
    return out;
  }

  void switchTo(int i) {
    if (i >= 0 && i < devs.length) cur = i;
  }

  // ---- build ----
  void _build() {
    final uses = <String>['core'];
    final u = lab['use'];
    if (u is List) {
      for (final x in u) {
        if (!uses.contains('$x')) uses.add('$x');
      }
    }
    final shared = <CmdDef>[];
    for (final name in uses) {
      final l = kCliModules[name];
      if (l == null) continue;
      for (final s in l) {
        final d = parseDefLine(s);
        if (d != null) shared.add(d);
      }
    }
    final extra = <CmdDef>[];
    final g = lab['grammar'];
    if (g is List) {
      for (final x in g) {
        final d = parseGrammarEntry(x);
        if (d != null) extra.add(d);
      }
    }
    final dl = lab['devices'];
    if (dl is! List) return;
    for (final raw in dl) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final id = '${m['id'] ?? ''}';
      final cfgRaw = m['config'];
      final cfg = _parseCfg(cfgRaw is List ? cfgRaw.map((e) => '$e').toList() : <String>[]);
      var host = id;
      for (final b in cfg) {
        if (b.head.toLowerCase().startsWith('hostname ')) host = b.head.substring(9).trim();
      }
      final sm = '${m['start_mode'] ?? 'privileged'}'.toLowerCase();
      final d = LabDev(id, '${m['kind'] ?? 'router'}', host, sm.startsWith('user') ? 'user' : 'priv', cfg, _clone(cfg));
      d.defs = [..._showDefs(m), ...extra, ...shared];
      devs.add(d);
    }
  }

  List<CmdDef> _showDefs(Map<String, dynamic> m) {
    final out = <CmdDef>[];
    final sh = m['show'];
    if (sh is! List) return out;
    for (final s in sh) {
      if (s is! Map) continue;
      final cmd = '${s['cmd'] ?? ''}'.trim().toLowerCase();
      if (cmd.isEmpty) continue;
      final vs = <Map<String, dynamic>>[];
      final v = s['variants'];
      if (v is List) {
        for (final x in v) {
          if (x is Map) vs.add(Map<String, dynamic>.from(x));
        }
      }
      out.add(CmdDef(
        modes: ['user', 'priv'],
        pat: cmd.split(RegExp(r'\s+')),
        action: 'show',
        show: ShowRule(_text(s['default']), vs),
      ));
    }
    return out;
  }

  // ---- prompt / run ----
  String prompt(LabDev d) {
    if (d.mode == 'user') return '${d.hostname}>';
    if (d.mode == 'priv') return '${d.hostname}#';
    return '${d.hostname}(${d.mode.startsWith('config') ? d.mode : 'config'})#';
  }

  String get promptText => prompt(dev);

  void run(String raw) {
    final d = dev;
    final t = raw.trim();
    if (t.endsWith('?')) {
      runHelp(raw.substring(0, raw.lastIndexOf('?')));
      return;
    }
    d.log.add(prompt(d) + raw);
    if (t.isEmpty) return;
    touched = true;
    d.history.add(t);
    d.log.addAll(_exec(d, raw, d.mode));
    if (d.log.length > 600) d.log.removeRange(0, d.log.length - 500);
  }

  void runHelp(String base) {
    final d = dev;
    d.log.add('${prompt(d)}$base?');
    d.log.addAll(allowHelp ? help(base) : ['% Help is disabled in this lab.']);
  }

  List<String> _exec(LabDev d, String raw, String mode) {
    var cmd = raw;
    var filt = '';
    final bar = raw.indexOf('|');
    if (bar >= 0) {
      cmd = raw.substring(0, bar);
      filt = raw.substring(bar + 1).trim();
    }
    final ms = RegExp(r'\S+').allMatches(cmd).toList();
    if (ms.isEmpty) return [];
    var toks = ms.map((m) => m.group(0)!).toList();
    var off = 0;
    var neg = false;
    if (toks[0].toLowerCase() == 'no') {
      if (!mode.startsWith('config')) {
        return _err(d, ms, 'invalid', 0, cmd, mode);
      }
      if (toks.length == 1) return ['% Incomplete command.'];
      neg = true;
      toks = toks.sublist(1);
      off = 1;
    }
    var res = _parse(d, toks, mode, neg);
    var useMode = mode;
    if (res.p == null && res.err == 'invalid' && mode.startsWith('config') && mode != 'config') {
      final r2 = _parse(d, toks, 'config', neg); // IOS lets global commands be typed in sub-modes
      if (r2.p != null) {
        res = r2;
        useMode = 'config';
      }
    }
    if (res.p == null) return _err(d, ms, res.err, res.tok + off, cmd, mode);
    if (useMode != mode) {
      d.mode = 'config';
      d.ctx = '';
    }
    var out = _apply(d, res.p!, neg);
    if (filt.isNotEmpty) out = _filter(out, filt);
    return out;
  }

  List<String> _err(LabDev d, List<RegExpMatch> ms, String err, int idx, String cmd, String mode) {
    if (err == 'incomplete') return ['% Incomplete command.'];
    if (err == 'ambiguous') return ['% Ambiguous command:  "${cmd.trim()}"'];
    if (!mode.startsWith('config') && idx == 0) {
      return [
        'Translating "${ms[0].group(0)}"...domain server (255.255.255.255)',
        '% Unknown command or computer name, or unable to find computer address',
      ];
    }
    final col = prompt(d).length + (idx < ms.length ? ms[idx].start : cmd.length);
    return [' ' * col + '^', "% Invalid input detected at '^' marker."];
  }

  // ---- parsing / narrowing ----
  _Nar _narrow(LabDev d, List<String> toks, String mode, bool neg) {
    final r = _Nar();
    var alive = <_P>[];
    for (final def in d.defs) {
      if (!_modeOk(def, mode)) continue;
      if (neg && def.action.isNotEmpty) continue;
      alive.add(_P(def, <String>[]));
    }
    for (var i = 0; i < toks.length; i++) {
      final tok = toks[i];
      final low = tok.toLowerCase();
      final lits = <String>{};
      var paramOk = false;
      for (final p in alive) {
        if (i < p.def.pat.length) {
          final t = p.def.pat[i];
          if (_isParam(t)) {
            if (_param(t, tok) != null) paramOk = true;
          } else {
            lits.add(t.toLowerCase());
          }
        }
      }
      var lit = '';
      if (lits.contains(low)) {
        lit = low;
      } else {
        final m = lits.where((x) => x.startsWith(low)).toList();
        if (m.length == 1) {
          lit = m.first;
        } else if (m.length > 1 && !paramOk) {
          r.err = 'ambiguous';
          r.tok = i;
          return r;
        }
      }
      final next = <_P>[];
      for (final p in alive) {
        final pat = p.def.pat;
        if (i >= pat.length) {
          if (pat.isNotEmpty && pat.last == '<rest>' && p.exp.length == pat.length) {
            final e = List<String>.of(p.exp);
            e[e.length - 1] = '${e.last} $tok';
            next.add(_P(p.def, e));
          }
          continue;
        }
        final t = pat[i];
        if (_isParam(t)) {
          final v = _param(t, tok);
          if (v != null) next.add(_P(p.def, [...p.exp, v]));
        } else if (lit.isNotEmpty && t.toLowerCase() == lit) {
          next.add(_P(p.def, [...p.exp, t]));
        }
      }
      if (next.isEmpty) {
        r.err = 'invalid';
        r.tok = i;
        return r;
      }
      alive = next;
    }
    r.alive = alive;
    return r;
  }

  bool _complete(_P p, bool neg) {
    final pat = p.def.pat;
    if (p.exp.length == pat.length) return true;
    if (neg && p.exp.length < pat.length) {
      for (var i = p.exp.length; i < pat.length; i++) {
        if (!_isParam(pat[i])) return false;
      }
      return true;
    }
    return false;
  }

  _Res _parse(LabDev d, List<String> toks, String mode, bool neg) {
    final r = _Res();
    final n = _narrow(d, toks, mode, neg);
    if (n.err.isNotEmpty) {
      r.err = n.err;
      r.tok = n.tok;
      return r;
    }
    for (final p in n.alive) {
      if (_complete(p, neg)) {
        r.p = p;
        return r;
      }
    }
    r.err = 'incomplete';
    return r;
  }

  // ---- config storage ----
  bool _global(LabDev d) => d.mode == 'config' || d.ctx.isEmpty;

  CfgBlock? _block(LabDev d) {
    for (final b in d.cfg) {
      if (_eq(b.head, d.ctx)) return b;
    }
    return null;
  }

  CfgBlock _ensureBlock(LabDev d, String head) {
    for (final b in d.cfg) {
      if (_eq(b.head, head)) return b;
    }
    final nb = CfgBlock(head);
    d.cfg.add(nb);
    d.saved = false;
    return nb;
  }

  List<String> _lines(LabDev d) {
    if (_global(d)) return [for (final b in d.cfg) b.head];
    final b = _block(d);
    return b == null ? <String>[] : b.lines;
  }

  void _add(LabDev d, String line) {
    if (_global(d)) {
      d.cfg.add(CfgBlock(line));
    } else {
      (_block(d) ?? _ensureBlock(d, d.ctx)).lines.add(line);
    }
    d.saved = false;
  }

  int _removeWhere(LabDev d, bool Function(String) test) {
    var n = 0;
    if (_global(d)) {
      final before = d.cfg.length;
      d.cfg.removeWhere((b) => b.lines.isEmpty && test(b.head));
      n = before - d.cfg.length;
    } else {
      final b = _block(d);
      if (b != null) {
        final before = b.lines.length;
        b.lines.removeWhere(test);
        n = before - b.lines.length;
      }
    }
    if (n > 0) d.saved = false;
    return n;
  }

  String _key(_P p) {
    if (p.def.key.isNotEmpty) return p.def.key;
    final pat = p.def.pat;
    var end = pat.length;
    while (end > 0 && _isParam(pat[end - 1])) {
      end--;
    }
    if (end == 0) return p.exp.join(' ');
    return p.exp.sublist(0, end).join(' ');
  }

  bool _ifOk(LabDev d, String head) {
    if (d.cfg.any((b) => _eq(b.head, head))) return true;
    final n = head.substring(10).toLowerCase();
    return n.startsWith('loopback') ||
        n.startsWith('vlan') ||
        n.startsWith('port-channel') ||
        n.startsWith('tunnel') ||
        n.contains('.');
  }

  List<String> _apply(LabDev d, _P p, bool neg) {
    final def = p.def;
    if (def.action.isNotEmpty) return _action(d, p);
    final text = p.exp.join(' ');
    if (def.enter.isNotEmpty) {
      if (!neg) {
        if (def.enter == 'config-if' && !_ifOk(d, text)) {
          return ['% Invalid interface type and number'];
        }
        final b = _ensureBlock(d, text);
        d.mode = def.enter;
        d.ctx = b.head;
      } else {
        final before = d.cfg.length;
        d.cfg.removeWhere((b) => _startsWord(b.head, text));
        if (d.cfg.length != before) d.saved = false;
      }
      return [];
    }
    if (!neg) {
      if (def.negStore) {
        _removeWhere(d, (l) => _eq(l, 'no $text'));
        return [];
      }
      if (def.replace) {
        final key = _key(p);
        _removeWhere(d, (l) => _startsWord(l, key));
      }
      _removeWhere(d, (l) => _eq(l, 'no $text'));
      if (!_lines(d).any((l) => _eq(l, text))) _add(d, text);
    } else {
      _removeWhere(d, (l) => _startsWord(l, text));
      if (def.negStore && !_lines(d).any((l) => _eq(l, 'no $text'))) _add(d, 'no $text');
    }
    return [];
  }

  List<String> _action(LabDev d, _P p) {
    switch (p.def.action) {
      case 'enable':
        d.mode = 'priv';
        return [];
      case 'disable':
        d.mode = 'user';
        return [];
      case 'conft':
        d.mode = 'config';
        d.ctx = '';
        return ['Enter configuration commands, one per line.  End with CNTL/Z.'];
      case 'exit':
        if (d.mode == 'config') {
          d.mode = 'priv';
        } else if (d.mode.startsWith('config')) {
          d.mode = 'config';
          d.ctx = '';
        } else if (d.mode == 'priv') {
          d.mode = 'user';
        }
        return [];
      case 'end':
        d.mode = 'priv';
        d.ctx = '';
        return [];
      case 'do':
        return _exec(d, p.exp[1], 'priv');
      case 'copy':
        d.startup = _clone(d.cfg);
        d.saved = true;
        return ['Destination filename [startup-config]? ', 'Building configuration...', '[OK]'];
      case 'hostname':
        return _setHostname(d, p.exp[1]);
      case 'noop':
        return [];
      case 'show_run':
        return _renderRun(d.cfg);
      case 'show_start':
        return _renderRun(d.startup);
      case 'show_run_if':
        return _showRunIf(d, p.exp.last);
      case 'show_ipbrief':
        return _ipBrief(d);
      case 'show':
        return _showAuthor(d, p.def.show);
      case 'vlanadd':
        return _vlanAdd(d, p.exp.last);
    }
    return [];
  }

  List<String> _setHostname(LabDev d, String n) {
    final i = d.cfg.indexWhere((b) => b.head.toLowerCase().startsWith('hostname '));
    if (i >= 0) {
      d.cfg[i].head = 'hostname $n';
    } else {
      d.cfg.insert(0, CfgBlock('hostname $n'));
    }
    d.hostname = n;
    d.saved = false;
    return [];
  }

  List<String> _showRunIf(LabDev d, String name) {
    final head = 'interface $name';
    for (final b in d.cfg) {
      if (_eq(b.head, head)) return _renderRun([b]);
    }
    return ["% Invalid input detected at '^' marker."];
  }

  List<String> _showAuthor(LabDev d, ShowRule? rule) {
    if (rule == null) return [];
    var out = rule.def;
    for (final v in rule.variants) {
      final w = v['when'];
      if (w is Map && cond(Map<String, dynamic>.from(w), d)) {
        out = _text(v['output']);
        break;
      }
    }
    out = out.replaceAll('{hostname}', d.hostname);
    return out.isEmpty ? <String>[] : out.split('\n');
  }

  List<String> _vlanAdd(LabDev d, String add) {
    final b = _block(d);
    if (b == null) return [];
    const base = 'switchport trunk allowed vlan ';
    final i = b.lines.indexWhere((l) => _norm(l).startsWith(base) && !_norm(l).startsWith('${base}add'));
    if (i >= 0) {
      b.lines[i] = '${b.lines[i]},$add';
    } else {
      b.lines.add('$base$add');
    }
    d.saved = false;
    return [];
  }

  List<String> _renderRun(List<CfgBlock> cfg) {
    final body = <String>['!'];
    for (final b in cfg) {
      body.add(b.head);
      for (final l in b.lines) {
        body.add(' $l');
      }
      if (b.lines.isNotEmpty || b.head.startsWith('interface ') || b.head.startsWith('router ')) body.add('!');
    }
    body.add('end');
    final size = body.fold<int>(0, (a, l) => a + l.length + 1);
    return ['Building configuration...', '', 'Current configuration : $size bytes', ...body];
  }

  List<String> _ipBrief(LabDev d) {
    final out = <String>['Interface                  IP-Address      OK? Method Status                Protocol'];
    for (final b in d.cfg) {
      if (!b.head.startsWith('interface ')) continue;
      final name = b.head.substring(10);
      var ip = 'unassigned', method = 'unset';
      for (final l in b.lines) {
        final w = _norm(l).split(' ');
        if (w.length >= 3 && w[0] == 'ip' && w[1] == 'address') {
          if (_isIp(w[2])) {
            ip = w[2];
            method = 'manual';
          } else if (w[2] == 'dhcp') {
            method = 'DHCP';
          }
        }
      }
      final down = b.lines.any((l) => _norm(l) == 'shutdown');
      out.add('${name.padRight(26)} ${ip.padRight(15)} YES ${method.padRight(6)} ${(down ? 'administratively down' : 'up').padRight(21)} ${down ? 'down' : 'up'}');
    }
    return out;
  }

  List<String> _filter(List<String> out, String f) {
    final m = RegExp(r'^(\S+)\s*(.*)$').firstMatch(f.trim());
    if (m == null) return out;
    final w = m.group(1)!.toLowerCase();
    final pat = m.group(2)!.trim().toLowerCase();
    String kind = '';
    for (final k in ['include', 'exclude', 'begin', 'section']) {
      if (k.startsWith(w)) {
        kind = k;
        break;
      }
    }
    if (kind.isEmpty) return ["% Invalid input detected at '^' marker."];
    if (pat.isEmpty) return ['% Incomplete command.'];
    bool hit(String l) => l.toLowerCase().contains(pat);
    if (kind == 'include') return out.where(hit).toList();
    if (kind == 'exclude') return out.where((l) => !hit(l)).toList();
    if (kind == 'begin') {
      final i = out.indexWhere(hit);
      return i < 0 ? <String>[] : out.sublist(i);
    }
    final res = <String>[];
    var i = 0;
    while (i < out.length) {
      var j = i + 1;
      while (j < out.length && out[j].startsWith(' ')) {
        j++;
      }
      final grp = out.sublist(i, j);
      if (grp.any(hit)) res.addAll(grp);
      i = j;
    }
    return res;
  }

  // ---- tab completion / "?" help ----
  String? complete(String line) {
    final d = dev;
    final ms = RegExp(r'\S+').allMatches(line).toList();
    if (ms.isEmpty || line.endsWith(' ')) return null;
    var toks = ms.map((m) => m.group(0)!).toList();
    var neg = false;
    if (toks.length > 1 && toks[0].toLowerCase() == 'no' && d.mode.startsWith('config')) {
      neg = true;
      toks = toks.sublist(1);
    }
    final last = toks.last;
    final low = last.toLowerCase();
    final pre = toks.sublist(0, toks.length - 1);
    final n = _narrow(d, pre, d.mode, neg);
    if (n.err.isNotEmpty) return null;
    final i = pre.length;
    final opts = <String>{};
    for (final p in n.alive) {
      if (i < p.def.pat.length) {
        final t = p.def.pat[i];
        if (!_isParam(t) && t.toLowerCase().startsWith(low)) opts.add(t);
      }
    }
    if (!neg && ms.length == 1 && d.mode.startsWith('config') && 'no'.startsWith(low)) opts.add('no');
    if (opts.isEmpty) return null;
    String pick;
    if (opts.length == 1) {
      pick = '${opts.first} ';
    } else {
      var lcp = opts.first;
      for (final o in opts) {
        while (!o.toLowerCase().startsWith(lcp.toLowerCase())) {
          lcp = lcp.substring(0, lcp.length - 1);
        }
      }
      if (lcp.length <= last.length) return null;
      pick = lcp;
    }
    return line.substring(0, ms.last.start) + pick;
  }

  List<String> help(String line) {
    final d = dev;
    final endsSp = line.isEmpty || line.endsWith(' ');
    var toks = RegExp(r'\S+').allMatches(line).map((m) => m.group(0)!).toList();
    var neg = false;
    if (toks.isNotEmpty && toks[0].toLowerCase() == 'no' && (toks.length > 1 || endsSp) && d.mode.startsWith('config')) {
      neg = true;
      toks = toks.sublist(1);
    }
    final pre = endsSp ? toks : toks.sublist(0, toks.length - 1);
    final n = _narrow(d, pre, d.mode, neg);
    if (n.err.isNotEmpty) return ['% Unrecognized command'];
    final i = pre.length;
    final prefix = endsSp ? '' : toks.last.toLowerCase();
    final lits = <String>{};
    final params = <String>{};
    var cr = false;
    for (final p in n.alive) {
      if (endsSp && _complete(p, neg)) cr = true;
      if (i < p.def.pat.length) {
        final t = p.def.pat[i];
        if (_isParam(t)) {
          if (endsSp) params.add(_paramHelp(t));
        } else if (t.toLowerCase().startsWith(prefix)) {
          lits.add(t);
        }
      }
    }
    if (!neg && d.mode.startsWith('config') && toks.isEmpty && endsSp) lits.add('no');
    final sorted = lits.toList()..sort();
    if (!endsSp) {
      return sorted.isEmpty ? ['% Unrecognized command'] : [sorted.join('  ')];
    }
    final out = <String>[for (final l in sorted) '  $l', for (final p in params) '  $p'];
    if (cr) out.add('  <cr>');
    return out.isEmpty ? ['% Unrecognized command'] : out;
  }

  // ---- conditions / grading ----
  /// [scopeIn]: the "in" block of a parent condition; children inherit it unless they set their own.
  bool cond(Map<String, dynamic> c, LabDev cur, [String? scopeIn]) {
    LabDev? found = cur;
    if (c['device'] != null) {
      found = null;
      for (final x in devs) {
        if (x.id == '${c['device']}') found = x;
      }
    }
    if (found == null) return false;
    final LabDev dv = found;
    final String? inStr = c['in'] != null ? '${c['in']}' : scopeIn;
    final List<CfgBlock>? inb =
        inStr == null ? null : dv.cfg.where((b) => labWild(normHead(inStr), b.head)).toList();
    bool lineIn(String pat) {
      final scope = inb;
      if (scope == null) return dv.cfg.any((b) => labWild(pat, b.head));
      return scope.any((b) => b.lines.any((l) => labWild(pat, l)));
    }

    final has = c['has'];
    if (has != null) {
      for (final s in (has is List ? has : [has])) {
        if (!lineIn('$s')) return false;
      }
    }
    final mis = c['missing'];
    if (mis != null) {
      for (final s in (mis is List ? mis : [mis])) {
        if (lineIn('$s')) return false;
      }
    }
    if (c['saved'] != null && dv.saved != (c['saved'] == true)) return false;
    final all = c['all'];
    if (all is List) {
      for (final x in all) {
        if (x is! Map || !cond(Map<String, dynamic>.from(x), dv, inStr)) return false;
      }
    }
    final any = c['any'];
    if (any is List && any.isNotEmpty) {
      var ok = false;
      for (final x in any) {
        if (x is Map && cond(Map<String, dynamic>.from(x), dv, inStr)) {
          ok = true;
          break;
        }
      }
      if (!ok) return false;
    }
    final not = c['not'];
    if (not is Map && cond(Map<String, dynamic>.from(not), dv, inStr)) return false;
    return true;
  }

  bool _goal(dynamic g) => g is Map && devs.isNotEmpty && cond(Map<String, dynamic>.from(g), devs.first);

  bool passed() {
    final g = lab['goals'];
    if (g is! List || g.isEmpty) return false;
    for (final x in g) {
      if (!_goal(x)) return false;
    }
    return true;
  }

  bool taskDone(String id) {
    final g = lab['goals'];
    if (g is! List) return false;
    var any = false;
    for (final x in g) {
      if (x is Map && '${x['task']}' == id) {
        any = true;
        if (!_goal(x)) return false;
      }
    }
    return any;
  }

  /// Runs the author's "solution" (used by the validator). Returns problems found.
  List<String> runSolution() {
    final probs = <String>[];
    final sol = lab['solution'];
    if (sol is! List || sol.isEmpty) return ['lab needs a "solution" (list of {device, commands})'];
    for (final s in sol) {
      if (s is! Map) continue;
      final idx = devs.indexWhere((x) => x.id == '${s['device']}');
      if (idx < 0) {
        probs.add('solution uses unknown device "${s['device']}"');
        continue;
      }
      cur = idx;
      final d = devs[idx];
      final cmds = s['commands'] is List ? (s['commands'] as List).map((e) => '$e').toList() : <String>[];
      if (cmds.isEmpty) continue;
      final f = cmds.first.trim().toLowerCase();
      if (!(f.startsWith('en') || f.startsWith('conf'))) {
        if (d.mode == 'user') run('enable');
        if (d.mode == 'priv') run('configure terminal');
      }
      for (final c in cmds) {
        final before = d.log.length;
        run(c);
        final added = d.log.sublist(before + 1);
        final bad = added.where((l) => l.startsWith('%') || l.startsWith('Translating')).toList();
        if (bad.isNotEmpty) {
          probs.add('solution command "$c" on ${d.id} is not accepted by the simulator (${bad.first}). Check the "use" modules or add it to "grammar".');
        }
      }
    }
    cur = 0;
    return probs;
  }
}

// ───────────────────────── validation (used by library.dart) ─────────────────────────
void _scanDevices(dynamic x, Set<String> ids, List<String> out, String at) {
  if (x is Map) {
    final d = x['device'];
    if (d is String && !ids.contains(d)) out.add('$at: refers to unknown device "$d"');
    for (final v in x.values) {
      _scanDevices(v, ids, out, at);
    }
  } else if (x is List) {
    for (final v in x) {
      _scanDevices(v, ids, out, at);
    }
  }
}

List<String> validateLab(dynamic raw, String at) {
  final e = <String>[];
  if (raw is! Map) {
    e.add('$at: type "lab" needs a "lab" object');
    return e;
  }
  final lab = Map<String, dynamic>.from(raw);
  final ids = <String>{};
  final devs = lab['devices'];
  if (devs is! List || devs.isEmpty) {
    e.add('$at: lab needs "devices" (at least one)');
  } else {
    for (var i = 0; i < devs.length; i++) {
      final d = devs[i];
      if (d is! Map) {
        e.add('$at: devices[$i] is not an object');
        continue;
      }
      final id = '${d['id'] ?? ''}'.trim();
      if (id.isEmpty) {
        e.add('$at: devices[$i] needs an "id"');
      } else if (!ids.add(id)) {
        e.add('$at: duplicate device id "$id"');
      }
      if (d['config'] != null && d['config'] is! List) e.add('$at: device "$id": "config" must be a list of lines');
      final sh = d['show'];
      if (sh != null) {
        if (sh is! List) {
          e.add('$at: device "$id": "show" must be a list');
        } else {
          for (var k = 0; k < sh.length; k++) {
            final s = sh[k];
            if (s is! Map || '${s['cmd'] ?? ''}'.trim().isEmpty) e.add('$at: device "$id" show[$k] needs "cmd"');
          }
        }
      }
    }
  }
  final goals = lab['goals'];
  if (goals is! List || goals.isEmpty) e.add('$at: lab needs "goals" (conditions that mean "solved")');
  final use = lab['use'];
  if (use is List) {
    for (final u in use) {
      if (!kCliModules.containsKey('$u')) e.add('$at: unknown module "$u" in "use" (${kCliModules.keys.join(', ')})');
    }
  }
  final gram = lab['grammar'];
  if (gram is List) {
    for (var i = 0; i < gram.length; i++) {
      if (parseGrammarEntry(gram[i]) == null) e.add('$at: grammar[$i] is not valid');
    }
  }
  final tasks = lab['tasks'];
  if (tasks is List && tasks.isNotEmpty && goals is List) {
    final tids = <String>{};
    for (final t in tasks) {
      if (t is Map) tids.add('${t['id']}');
    }
    for (final g in goals) {
      if (g is Map && g['task'] != null && !tids.contains('${g['task']}')) {
        e.add('$at: goal refers to unknown task "${g['task']}"');
      }
    }
  }
  if (ids.isNotEmpty) _scanDevices(lab, ids, e, at);
  if (e.isNotEmpty) return e;
  try {
    final s = LabSession(lab);
    if (s.passed()) e.add('$at: goals are already satisfied before any command (nothing to solve)');
    final probs = s.runSolution();
    for (final p in probs) {
      e.add('$at: $p');
    }
    if (probs.isEmpty && !s.passed()) e.add('$at: the "solution" does not satisfy the "goals"');
  } catch (x) {
    e.add('$at: lab could not be simulated ($x)');
  }
  return e;
}
