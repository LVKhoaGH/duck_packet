#!/usr/bin/env python3
"""Patches lib/library.dart, lib/game_session_screen.dart, lib/practice_tab.dart
for the new question types (multi_select, lab).

Run from the project root (the folder that contains pubspec.yaml):
    python apply_lab_patch.py
Every edit asserts that the text to replace occurs exactly once; nothing is written
to a file unless ALL of its edits succeed. Safe to run twice (already-patched files are skipped).
"""
import re
import sys
import os

LIB = os.path.join('lib')


def load(name):
    p = os.path.join(LIB, name)
    raw = open(p, 'rb').read().decode('utf-8')
    return p, raw.replace('\r\n', '\n'), ('\r\n' in raw)


def save(p, s, crlf):
    if crlf:
        s = s.replace('\n', '\r\n')
    open(p, 'wb').write(s.encode('utf-8'))


def rep(s, old, new, label):
    n = s.count(old)
    assert n == 1, f'[{label}] expected exactly 1 match, found {n}: {old[:70]!r}'
    return s.replace(old, new)


def rep_re(s, pattern, repl, label):
    out, n = re.subn(pattern, repl, s, count=0)
    assert n == 1, f'[{label}] expected exactly 1 regex match, found {n}: {pattern[:70]!r}'
    return out


# ───────────────────────── library.dart ─────────────────────────
def patch_library():
    p, s, crlf = load('library.dart')
    if "validateLab(" in s:
        print('library.dart: already patched, skipped')
        return
    s = rep(s, "import 'models.dart';", "import 'models.dart';\nimport 'cli_engine.dart';", 'library import')
    new_branch = """  } else if (type == 'multi_select') {
    final ans = _l(q['correct_answers']).map((x) => '$x').toList();
    if (options.length < 3) e.add('$at: multi_select needs 3+ options');
    if (ans.length < 2) e.add('$at: multi_select needs "correct_answers" with 2+ entries (for 1 answer use multiple_choice)');
    if (ans.length >= options.length) e.add('$at: multi_select must have fewer correct answers than options');
    if (ans.toSet().length != ans.length) e.add('$at: correct_answers must all be different');
    for (final a in ans) {
      if (!options.contains(a)) e.add('$at: correct answer "$a" is not in options');
    }
  } else if (type == 'lab') {
    e.addAll(validateLab(q['lab'], at));
  } else {
    e.add('$at: unknown type "$type" (use reorder, match_pairs, fill_code, multiple_choice, categorize, multi_select, lab)');
  }"""
    old = """  } else {
    e.add('$at: unknown type "$type" (use reorder, match_pairs, fill_code, multiple_choice, categorize)');
  }"""
    s = rep(s, old, new_branch, 'library unknown-type branch')
    save(p, s, crlf)
    print('library.dart: patched')


# ───────────────────────── game_session_screen.dart ─────────────────────────
def patch_session():
    p, s, crlf = load('game_session_screen.dart')
    if 'LabQuestion(' in s:
        print('game_session_screen.dart: already patched, skipped')
        return
    s = rep(s, "import 'duck.dart';",
            "import 'duck.dart';\nimport 'lab_screen.dart';\nimport 'multi_select_question.dart';\nimport 'cli_engine.dart';",
            'session imports')
    s = rep(s, "return 'Sort into the right group';",
            "return 'Sort into the right group';\n      case 'multi_select':\n        return 'Select all that apply';\n      case 'lab':\n        return 'Complete the lab';",
            'session _instruction')
    s = rep_re(s, r"\n(\s*)default:\n(\s*)return q\.correctAnswer;",
               lambda m: ("\n" + m.group(1) + "case 'multi_select':\n" + m.group(2) +
                          "return q.correctAnswers.join('\\n');\n" + m.group(1) + "case 'lab':\n" + m.group(2) +
                          "return labSolutionText(q.lab);\n" + m.group(1) + "default:\n" + m.group(2) +
                          "return q.correctAnswer;"),
               'session _answerText')
    s = rep(s, "CategorizeQuestion(q: q, onAnswer: _onAnswer)",
            "CategorizeQuestion(q: q, onAnswer: _onAnswer)\n"
            "                      else if (q.type == 'multi_select')\n"
            "                        MultiSelectQuestion(q: q, onAnswer: _onAnswer)\n"
            "                      else if (q.type == 'lab')\n"
            "                        LabQuestion(q: q, onAnswer: _onAnswer)",
            'session build branches')
    save(p, s, crlf)
    print('game_session_screen.dart: patched')


# ───────────────────────── practice_tab.dart ─────────────────────────
LABS_TILE = """      tile(
        Icons.terminal_rounded,
        AppColors.terminalBg,
        'Labs',
        labPool.isEmpty ? 'No labs in this course yet' : 'Hands-on CLI scenarios',
        labPool.length,
        labPool.isEmpty
            ? null
            : () => _start(context, 'Labs', (labPool.toList()..shuffle()).take(3).toList(), SessionMode.practice),
      ),
"""


def patch_practice():
    p, s, crlf = load('practice_tab.dart')
    if 'labPool' in s:
        print('practice_tab.dart: already patched, skipped')
        return
    s = rep(s, "...n.questions];",
            "...n.questions.where((q) => q.type != 'lab')];\n"
            "    final labPool = <Question>[for (final n in c.allNodes) for (final q in n.questions) if (q.type == 'lab') q];",
            'practice mixPool')
    s = rep_re(s, r"(\n[ \t]*)const SizedBox\(height: 14\),(\n[ \t]*const Text\('Domain mastery')",
               lambda m: "\n" + LABS_TILE.rstrip('\n') + m.group(1) + "const SizedBox(height: 14)," + m.group(2),
               'practice labs tile')
    save(p, s, crlf)
    print('practice_tab.dart: patched')


if __name__ == '__main__':
    if not os.path.isdir(LIB):
        sys.exit('Run this from the project root (folder with pubspec.yaml and lib/).')
    try:
        patch_library()
        patch_session()
        patch_practice()
    except AssertionError as err:
        sys.exit('PATCH FAILED, file not written: ' + str(err))
    print('Done. Now: flutter pub get (not needed) -> flutter analyze -> stop the app fully and run again.')
