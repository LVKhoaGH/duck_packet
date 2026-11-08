// ai_service.dart  (ĐÈ BẢN CŨ)  Nhiều API key, nhiều nhà cung cấp, tự xoay vòng khi key lỗi/hết lượt.
// Key lưu trong box Hive riêng 'ai' (không nằm trong Backup).
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

class AiMsg {
  final bool user;
  final String text;
  final bool error;
  AiMsg(this.user, this.text, {this.error = false});
}

class AiError implements Exception {
  final String message;
  final int status;
  AiError(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class AiProvider {
  final String id, name, base, model;
  const AiProvider(this.id, this.name, this.base, this.model);
}

/// Tên model do nhà cung cấp đổi thường xuyên: người dùng sửa được khi thêm key.
const List<AiProvider> kProviders = [
  AiProvider('gemini', 'Google Gemini', '', 'gemini-2.5-flash'),
  AiProvider('groq', 'Groq', 'https://api.groq.com/openai/v1', 'llama-3.3-70b-versatile'),
  AiProvider('openrouter', 'OpenRouter', 'https://openrouter.ai/api/v1', 'meta-llama/llama-3.3-70b-instruct:free'),
  AiProvider('openai', 'OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini'),
  AiProvider('xai', 'xAI Grok', 'https://api.x.ai/v1', 'grok-3-mini'),
  AiProvider('custom', 'Custom (OpenAI-compatible)', '', ''),
];

AiProvider providerOf(String id) => kProviders.firstWhere((p) => p.id == id, orElse: () => kProviders.first);

class AiKey {
  final String id, provider, key, model, base;
  AiKey({required this.id, required this.provider, required this.key, required this.model, this.base = ''});
  factory AiKey.fromJson(Map<String, dynamic> j) => AiKey(
        id: '${j['id']}',
        provider: '${j['provider']}',
        key: '${j['key']}',
        model: '${j['model']}',
        base: '${j['base'] ?? ''}',
      );
  Map<String, dynamic> toJson() => {'id': id, 'provider': provider, 'key': key, 'model': model, 'base': base};
  String get tail => key.length <= 4 ? key : key.substring(key.length - 4);
  String get label => '${providerOf(provider).name}  ····$tail';
}

class AiService {
  static const String _system =
      'You are the study assistant inside DuckPacket, an app for the Cisco CCNP Enterprise '
      'ENCOR 350-401 exam. Answer in the same language the student writes in (Vietnamese if they '
      'write Vietnamese) and keep technical terms and CLI commands in English. Be concise and '
      'accurate. If you are not sure, say so instead of guessing. Use short paragraphs and simple '
      'bullet points.';

  static const Duration _timeout = Duration(seconds: 30);
  static int _rr = 0; // vòng xoay: mỗi câu hỏi bắt đầu từ key kế tiếp

  static Future<Box> _box() async => Hive.isBoxOpen('ai') ? Hive.box('ai') : await Hive.openBox('ai');

  static Future<List<AiKey>> keys() async {
    final b = await _box();
    final raw = b.get('keys');
    if (raw is String && raw.isNotEmpty) {
      try {
        return (jsonDecode(raw) as List).map((e) => AiKey.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      } catch (_) {}
    }
    // Chuyển từ bản cũ (1 key Gemini).
    final old = b.get('key');
    if (old is String && old.trim().isNotEmpty) {
      final m = b.get('model');
      final k = AiKey(
          id: 'k0',
          provider: 'gemini',
          key: old.trim(),
          model: (m is String && m.trim().isNotEmpty && m != 'gemini-flash-latest') ? m.trim() : providerOf('gemini').model);
      await _save([k]);
      await b.delete('key');
      return [k];
    }
    return [];
  }

  static Future<void> _save(List<AiKey> l) async => (await _box()).put('keys', jsonEncode(l.map((e) => e.toJson()).toList()));

  static Future<void> add(AiKey k) async => _save([...await keys(), k]);

  static Future<void> remove(String id) async => _save((await keys()).where((k) => k.id != id).toList());

  /// Hỏi AI. Thử lần lượt các key (bắt đầu từ key kế tiếp trong vòng xoay); key nào lỗi/hết lượt thì sang key khác.
  /// only: chỉ dùng các key này (để TEST một key trước khi lưu).
  static Future<String> ask(List<AiMsg> history, {String? contextText, List<AiKey>? only}) async {
    final list = only ?? await keys();
    if (list.isEmpty) throw AiError('No API key.');
    final start = _rr % list.length;
    _rr++;
    AiError? last;
    for (var i = 0; i < list.length; i++) {
      final k = list[(start + i) % list.length];
      try {
        return await _askOne(k, history, contextText);
      } on AiError catch (e) {
        last = e;
      }
    }
    final tried = list.length > 1 ? '  (tried ${list.length} keys)' : '';
    throw AiError('${last!.message}$tried', last.status);
  }

  static String _sys(String? ctx) => ctx == null || ctx.trim().isEmpty
      ? _system
      : '$_system\n\nThe student is asking about this question from the app:\n$ctx';

  static Future<String> _askOne(AiKey k, List<AiMsg> history, String? ctx) async {
    final msgs = history.where((m) => !m.error).toList();
    http.Response res;
    try {
      if (k.provider == 'gemini') {
        final uri = Uri.https('generativelanguage.googleapis.com', '/v1beta/models/${k.model}:generateContent', {'key': k.key});
        res = await http
            .post(uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'system_instruction': {
                    'parts': [
                      {'text': _sys(ctx)}
                    ]
                  },
                  'contents': [
                    for (final m in msgs)
                      {
                        'role': m.user ? 'user' : 'model',
                        'parts': [
                          {'text': m.text}
                        ]
                      }
                  ],
                }))
            .timeout(_timeout);
      } else {
        final base = (k.base.isNotEmpty ? k.base : providerOf(k.provider).base).replaceAll(RegExp(r'/+$'), '');
        res = await http
            .post(Uri.parse('$base/chat/completions'),
                headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${k.key}'},
                body: jsonEncode({
                  'model': k.model,
                  'messages': [
                    {'role': 'system', 'content': _sys(ctx)},
                    for (final m in msgs) {'role': m.user ? 'user' : 'assistant', 'content': m.text},
                  ],
                }))
            .timeout(_timeout);
      }
    } catch (e) {
      throw AiError('${providerOf(k.provider).name}: no connection, timeout, or the browser blocked the request. ($e)');
    }

    dynamic data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (res.statusCode != 200) {
      var raw = '';
      if (data is Map && data['error'] is Map) raw = ('${data['error']['message'] ?? ''}');
      if (data is Map && data['error'] is String) raw = '${data['error']}';
      throw AiError('${providerOf(k.provider).name}: ${_hint(res.statusCode, raw)}', res.statusCode);
    }
    String text = '';
    if (k.provider == 'gemini') {
      final cands = (data is Map) ? data['candidates'] : null;
      if (cands is List && cands.isNotEmpty) {
        final content = cands[0]['content'];
        final parts = (content is Map) ? content['parts'] : null;
        if (parts is List) text = parts.map((p) => (p is Map ? (p['text'] ?? '') : '').toString()).join().trim();
      }
    } else {
      final ch = (data is Map) ? data['choices'] : null;
      if (ch is List && ch.isNotEmpty && ch[0] is Map && ch[0]['message'] is Map) {
        text = '${ch[0]['message']['content'] ?? ''}'.trim();
      }
    }
    if (text.isEmpty) throw AiError('${providerOf(k.provider).name}: empty answer (it may have been blocked).', 200);
    return text;
  }

  static String _hint(int code, String raw) {
    final low = raw.toLowerCase();
    if (code == 400 && low.contains('api key')) return 'API key not valid. Check that you copied the whole key. ($raw)';
    if (code == 400) return 'Bad request. $raw';
    if (code == 401 || code == 403) return 'Key rejected or not allowed in your region/account. $raw';
    if (code == 404) return 'Model not found: change the model name. $raw';
    if (code == 429) return 'Rate limit reached (the free tier has limits). $raw';
    if (code >= 500) return 'Server error ($code). Try again later.';
    return 'Error $code. $raw';
  }
}
