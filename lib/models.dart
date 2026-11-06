class PairItem {
  final String left, right;
  PairItem(this.left, this.right);
  factory PairItem.fromJson(Map<String, dynamic> j) => PairItem(j['left'], j['right']);
  Map<String, dynamic> toJson() => {'left': left, 'right': right};
}

class Question {
  /// reorder | match_pairs | fill_code | multiple_choice | categorize | multi_select | lab
  final String type;
  final String prompt, explanation;
  final List<String> items, options;
  final List<int> correctOrder;
  final List<PairItem> pairs;
  final String template, correctAnswer;

  /// multi_select: every correct option ("Choose two" = 2 entries).
  final List<String> correctAnswers;

  /// lab: the whole "lab" object, kept raw so new lab fields never break old files.
  final Map<String, dynamic> lab;

  Question({
    required this.type,
    required this.prompt,
    required this.explanation,
    this.items = const [],
    this.options = const [],
    this.correctOrder = const [],
    this.pairs = const [],
    this.template = '',
    this.correctAnswer = '',
    this.correctAnswers = const [],
    this.lab = const <String, dynamic>{},
  });

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        type: j['type'],
        prompt: j['prompt'] ?? '',
        explanation: j['explanation'] ?? '',
        items: List<String>.from(j['items'] ?? []),
        options: List<String>.from(j['options'] ?? []),
        correctOrder: List<int>.from(j['correct_order'] ?? []),
        pairs: (j['pairs'] as List? ?? []).map((e) => PairItem.fromJson(Map<String, dynamic>.from(e))).toList(),
        template: j['template'] ?? '',
        correctAnswer: j['correct_answer'] ?? '',
        correctAnswers: (j['correct_answers'] as List? ?? []).map((e) => '$e').toList(),
        lab: j['lab'] is Map ? Map<String, dynamic>.from(j['lab'] as Map) : const <String, dynamic>{},
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'prompt': prompt,
        'explanation': explanation,
        'items': items,
        'options': options,
        'correct_order': correctOrder,
        'pairs': pairs.map((e) => e.toJson()).toList(),
        'template': template,
        'correct_answer': correctAnswer,
        'correct_answers': correctAnswers,
        'lab': lab,
      };
}

/// One swipeable lesson card. Kept as a raw map so new card types never break old files.
/// type: text | flow | code | compare | tip | warn
class LessonCard {
  final Map<String, dynamic> m;
  LessonCard(this.m);
  String _s(String k) => (m[k] ?? '').toString();
  String get type => m['type'] == null ? 'text' : m['type'].toString();
  String get title => _s('title');
  String get body => _s('body');
  String get code => _s('code');
  String get note => _s('note');
  List<String> get bullets => ((m['bullets'] as List?) ?? const []).map((e) => '$e').toList();
  List<String> get headers => ((m['headers'] as List?) ?? const []).map((e) => '$e').toList();
  List<List<String>> get rows =>
      ((m['rows'] as List?) ?? const []).map((r) => (r as List).map((e) => '$e').toList()).toList();
  // steps: ["text", ...] or [{"who": "Edge node", "do": "gui Map-Request"}, ...]
  List<MapEntry<String, String>> get steps => ((m['steps'] as List?) ?? const []).map((e) {
        if (e is Map) return MapEntry<String, String>('${e['who'] ?? ''}', '${e['do'] ?? e['text'] ?? ''}');
        return MapEntry<String, String>('', '$e');
      }).toList();
  Map<String, dynamic> toJson() => m;
}

class GlossaryItem {
  final String term, def, cmd, tag;
  GlossaryItem({required this.term, required this.def, this.cmd = '', this.tag = ''});
  factory GlossaryItem.fromJson(Map<String, dynamic> j) => GlossaryItem(
        term: '${j['term'] ?? ''}',
        def: '${j['def'] ?? ''}',
        cmd: '${j['cmd'] ?? ''}',
        tag: '${j['tag'] ?? ''}',
      );
  Map<String, dynamic> toJson() => {'term': term, 'def': def, 'cmd': cmd, 'tag': tag};
}

class CourseNode {
  final String id, title, icon;
  final List<Question> questions;
  final List<LessonCard> lesson;
  CourseNode({required this.id, required this.title, required this.icon, required this.questions, this.lesson = const []});
  factory CourseNode.fromJson(Map<String, dynamic> j) => CourseNode(
        id: j['node_id'],
        title: j['node_title'],
        icon: j['icon'] ?? 'router.svg',
        questions: (j['questions'] as List? ?? []).map((e) => Question.fromJson(Map<String, dynamic>.from(e))).toList(),
        lesson: (j['lesson'] as List? ?? []).map((e) => LessonCard(Map<String, dynamic>.from(e))).toList(),
      );
  Map<String, dynamic> toJson() => {
        'node_id': id,
        'node_title': title,
        'icon': icon,
        'questions': questions.map((e) => e.toJson()).toList(),
        'lesson': lesson.map((e) => e.toJson()).toList(),
      };
}

class Chapter {
  final String id, title;
  final List<CourseNode> nodes;
  Chapter({required this.id, required this.title, required this.nodes});
  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
        id: j['chapter_id'],
        title: j['chapter_title'],
        nodes: (j['nodes'] as List? ?? []).map((e) => CourseNode.fromJson(Map<String, dynamic>.from(e))).toList(),
      );
  Map<String, dynamic> toJson() =>
      {'chapter_id': id, 'chapter_title': title, 'nodes': nodes.map((e) => e.toJson()).toList()};
}

class Course {
  final String id, title;
  final List<Chapter> chapters;
  final List<GlossaryItem> glossary;
  Course({required this.id, required this.title, required this.chapters, this.glossary = const []});
  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: '${j['course_id'] ?? 'course'}',
        title: '${j['course_title'] ?? 'Course'}',
        chapters: (j['chapters'] as List? ?? []).map((e) => Chapter.fromJson(Map<String, dynamic>.from(e))).toList(),
        glossary: (j['glossary'] as List? ?? []).map((e) => GlossaryItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      );
  Map<String, dynamic> toJson() => {
        'course_id': id,
        'course_title': title,
        'chapters': chapters.map((e) => e.toJson()).toList(),
        'glossary': glossary.map((e) => e.toJson()).toList(),
      };
  List<CourseNode> get allNodes => chapters.expand((c) => c.nodes).toList();
}
