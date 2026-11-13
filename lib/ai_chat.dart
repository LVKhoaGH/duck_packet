// ai_chat.dart  (ĐÈ BẢN CŨ)
// Nút tròn AI + hướng dẫn lấy key + quản lý NHIỀU key (xoay vòng) + khung chat.
// File này tự chọn tiếng Anh/Việt theo Settings (không dùng lớp Text của i18n).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_service.dart';
import 'settings.dart';
import 'theme.dart';
import 'widgets.dart';

const String kKeyLink = 'https://aistudio.google.com/apikey';

/// Nút tròn góc dưới bên phải. Đặt BÊN TRONG một Stack.
class AiFab extends StatelessWidget {
  final double right, bottom;
  const AiFab({super.key, this.right = 16, this.bottom = 16});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: right,
      bottom: bottom,
      child: PressScale(
        onTap: () => showAiSheet(context),
        child: Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(7),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.primaryShadow, offset: Offset(0, 4))],
          ),
          child: Image.asset('assets/mascot/moods/duck_happy.png', fit: BoxFit.contain),
        ),
      ),
    );
  }
}

Future<void> showAiSheet(BuildContext context, {String? contextText}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    clipBehavior: Clip.antiAlias,
    constraints: const BoxConstraints(maxWidth: 720),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => FractionallySizedBox(heightFactor: 0.94, child: AiSheet(contextText: contextText)),
  );
}

class AiSheet extends ConsumerStatefulWidget {
  final String? contextText;
  const AiSheet({super.key, this.contextText});
  @override
  ConsumerState<AiSheet> createState() => _AiSheetState();
}

class _AiSheetState extends ConsumerState<AiSheet> {
  bool _loaded = false;
  List<AiKey> _keys = [];
  bool _setup = false; // đang ở màn quản lý key
  bool _testing = false, _busy = false, _obscure = true;
  String? _setupErr;
  String _prov = 'gemini';
  final List<AiMsg> _msgs = [];
  final _input = TextEditingController();
  final _keyCtl = TextEditingController();
  final _modelCtl = TextEditingController();
  final _baseCtl = TextEditingController();
  final _scroll = ScrollController();

  bool get _hasKey => _keys.isNotEmpty;
  bool get _vi => ref.read(settingsProvider).lang == 'vi';
  String _t(String en, String vi) => _vi ? vi : en;

  @override
  void initState() {
    super.initState();
    _modelCtl.text = providerOf(_prov).model;
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _keyCtl.dispose();
    _modelCtl.dispose();
    _baseCtl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final k = await AiService.keys();
    if (!mounted) return;
    setState(() {
      _keys = k;
      _loaded = true;
      _setup = k.isEmpty;
    });
  }

  void _pickProvider(String id) {
    setState(() {
      _prov = id;
      _modelCtl.text = providerOf(id).model;
    });
  }

  Future<void> _addKey() async {
    final key = _keyCtl.text.trim();
    if (key.isEmpty) return;
    final model = _modelCtl.text.trim().isEmpty ? providerOf(_prov).model : _modelCtl.text.trim();
    final k = AiKey(
      id: 'k${DateTime.now().microsecondsSinceEpoch}',
      provider: _prov,
      key: key,
      model: model,
      base: _prov == 'custom' ? _baseCtl.text.trim() : '',
    );
    if (_prov == 'custom' && k.base.isEmpty) {
      setState(() => _setupErr = _t('Custom needs a base URL.', 'Loại Custom cần nhập base URL.'));
      return;
    }
    setState(() {
      _testing = true;
      _setupErr = null;
    });
    try {
      await AiService.ask([AiMsg(true, 'Reply with the single word: OK')], only: [k]);
      await _saved(k);
    } on AiError catch (e) {
      if (e.status == 429) {
        await _saved(k); // key hợp lệ nhưng đang hết lượt: vẫn lưu
      } else if (mounted) {
        setState(() => _setupErr = e.message);
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _saved(AiKey k) async {
    await AiService.add(k);
    final l = await AiService.keys();
    if (!mounted) return;
    setState(() {
      _keys = l;
      _keyCtl.clear();
      _setup = false;
    });
  }

  Future<void> _removeKey(String id) async {
    await AiService.remove(id);
    final l = await AiService.keys();
    if (!mounted) return;
    setState(() {
      _keys = l;
      if (l.isEmpty) _setup = true;
    });
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _msgs.add(AiMsg(true, text));
      _busy = true;
      _input.clear();
    });
    _toBottom();
    try {
      final r = await AiService.ask(_msgs, contextText: widget.contextText);
      if (!mounted) return;
      setState(() => _msgs.add(AiMsg(false, r)));
    } on AiError catch (e) {
      if (!mounted) return;
      setState(() {
        _msgs.removeLast(); // bỏ câu hỏi lỗi, trả lại vào ô nhập
        _input.text = text;
        _msgs.add(AiMsg(false, e.message, error: true));
      });
    } finally {
      if (mounted) setState(() => _busy = false);
      _toBottom();
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  String _clean(String s) => s
      .replaceAll('**', '')
      .replaceAll(RegExp(r'^\s*[\*\-]\s+', multiLine: true), '• ')
      .replaceAll(RegExp(r'^#+\s*', multiLine: true), '');

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsProvider); // đổi ngôn ngữ thì vẽ lại
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(children: [
        _header(),
        Divider(height: 1, color: AppColors.line),
        Expanded(
          child: !_loaded ? const Center(child: CircularProgressIndicator()) : (_setup ? _setupView() : _chatView()),
        ),
      ]),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Row(children: [
          SizedBox(width: 36, height: 36, child: Image.asset('assets/mascot/moods/duck_happy.png')),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_t('AI assistant', 'Trợ lý AI'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
          ),
          if (_loaded && _hasKey && !_setup)
            IconButton(
              tooltip: _t('API keys', 'Quản lý API key'),
              icon: Icon(Icons.key_rounded, color: AppColors.sub),
              onPressed: () => setState(() {
                _setup = true;
                _setupErr = null;
              }),
            ),
          IconButton(icon: Icon(Icons.close_rounded, color: AppColors.sub), onPressed: () => Navigator.pop(context)),
        ]),
      );

  // ---------------- Quản lý key + hướng dẫn ----------------
  Widget _step(int n, String text, {Widget? extra}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(text, style: TextStyle(fontSize: 15, height: 1.35, color: AppColors.ink)),
              ),
              if (extra != null) extra,
            ]),
          ),
        ]),
      );

  Widget _tutorial() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _step(
          1,
          _t('Open Google AI Studio in your browser:', 'Mở Google AI Studio trên trình duyệt:'),
          extra: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.tint, borderRadius: BorderRadius.circular(10)),
                  child: const Text('aistudio.google.com/apikey',
                      style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13, color: AppColors.primaryShadow)),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(_t('Copy link', 'Chép link')),
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: kKeyLink));
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_t('Link copied', 'Đã chép link')), duration: const Duration(seconds: 1)));
                },
              ),
            ]),
          ),
        ),
        _step(2, _t('Sign in with your Google account.', 'Đăng nhập bằng tài khoản Google.')),
        _step(3, _t('Tap "Create API key" (choose or create a project if it asks).',
            'Bấm "Create API key" (chọn hoặc tạo project nếu được hỏi).')),
        _step(4, _t('Copy the key: a long text, usually starting with AIza.', 'Copy key: một chuỗi dài, thường bắt đầu bằng AIza.')),
        _step(5, _t('Paste it below, keep provider = Google Gemini, tap Add & test.',
            'Dán vào ô bên dưới, giữ nhà cung cấp là Google Gemini, bấm Add & test.')),
        Text(
            _t('Other providers (Groq, OpenRouter, ...) work too: create a key on their website and pick them in the list. '
                'Their free plans and model names change, so check their site.',
                'Nhà cung cấp khác (Groq, OpenRouter, ...) cũng dùng được: tạo key trên trang của họ rồi chọn trong danh sách. '
                    'Gói miễn phí và tên model của họ hay thay đổi, hãy xem trên trang của họ.'),
            style: TextStyle(fontSize: 13, height: 1.35, color: AppColors.mid)),
      ]);

  Widget _setupView() {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
      Text(_t('API keys (free)', 'API key (miễn phí)'),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
      const SizedBox(height: 4),
      Text(
          _t('Add one or more of YOUR OWN keys. The app tries them in turn and skips a key that errors or runs out of quota.',
              'Thêm một hoặc nhiều key CỦA BẠN. App dùng lần lượt, key nào lỗi hoặc hết lượt sẽ được bỏ qua.'),
          style: TextStyle(fontSize: 14, color: AppColors.mid, height: 1.3)),
      const SizedBox(height: 12),
      for (final k in _keys)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
          decoration: duoCard(border: AppColors.line, radius: 12),
          child: Row(children: [
            const Icon(Icons.vpn_key_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(k.label, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                Text(k.model, style: TextStyle(fontSize: 12, color: AppColors.sub)),
              ]),
            ),
            IconButton(
              tooltip: _t('Remove', 'Xóa'),
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              onPressed: () => _removeKey(k.id),
            ),
          ]),
        ),
      const SizedBox(height: 6),
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey(_keys.isEmpty),
          initiallyExpanded: _keys.isEmpty,
          tilePadding: EdgeInsets.zero,
          title: Text(_t('How to get a free key', 'Cách lấy key miễn phí'),
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.secondary)),
          children: [_tutorial()],
        ),
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.streakTint, borderRadius: BorderRadius.circular(12)),
        child: Text(
          _t(
              'Keep your keys private: never share them or post them on GitHub or in screenshots. Free tiers have usage limits, '
                  'and some providers may use free-tier content to improve their products, so do not send private data. '
                  'Keys are stored only on this device. Use your own keys: creating many accounts just to dodge limits may break the provider rules.',
              'Giữ key riêng tư: không chia sẻ, không đăng lên GitHub hay ảnh chụp màn hình. Gói miễn phí có giới hạn lượt dùng, '
                  'và một số nhà cung cấp có thể dùng nội dung của gói miễn phí để cải thiện sản phẩm, nên đừng gửi dữ liệu riêng tư. '
                  'Key chỉ lưu trên thiết bị này. Hãy dùng key của chính bạn: tạo nhiều tài khoản chỉ để né giới hạn có thể vi phạm quy định của nhà cung cấp.'),
          style: const TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF7A5B00)),
        ),
      ),
      const SizedBox(height: 16),
      Text(_t('Add a key', 'Thêm key'),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _prov,
        decoration: InputDecoration(
          labelText: _t('Provider', 'Nhà cung cấp'),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: [for (final p in kProviders) DropdownMenuItem(value: p.id, child: Text(p.name))],
        onChanged: (v) {
          if (v != null) _pickProvider(v);
        },
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _keyCtl,
        obscureText: _obscure,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: 'API key',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _modelCtl,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: _t('Model (change only if it errors)', 'Model (chỉ đổi khi báo lỗi)'),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      if (_prov == 'custom') ...[
        const SizedBox(height: 10),
        TextField(
          controller: _baseCtl,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Base URL (https://.../v1)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
      if (_setupErr != null) ...[
        const SizedBox(height: 10),
        Text(_setupErr!, style: const TextStyle(color: AppColors.error, fontSize: 14, height: 1.3)),
      ],
      const SizedBox(height: 16),
      Button3D(
        label: _testing ? _t('Testing...', 'Đang thử...') : 'Add & test',
        color: AppColors.primary,
        shadow: AppColors.primaryShadow,
        textColor: Colors.white,
        onPressed: (_testing || _keyCtl.text.trim().isEmpty) ? null : _addKey,
      ),
      if (_hasKey) ...[
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _setup = false),
            child: Text(_t('Back to chat', 'Về khung chat')),
          ),
        ),
      ],
    ]);
  }

  // ---------------- Khung chat ----------------
  List<String> get _suggestions {
    if (widget.contextText != null) {
      return _vi
          ? ['Giải thích dễ hiểu hơn', 'Cho mình một ví dụ', 'Vì sao các đáp án kia sai?']
          : ['Explain it more simply', 'Give me an example', 'Why are the other options wrong?'];
    }
    return _vi
        ? ['Phân biệt OSPF và EIGRP', 'Giải thích VXLAN và LISP trong SD-Access', 'Cách chọn đường BGP?']
        : ['OSPF vs EIGRP', 'Explain VXLAN and LISP in SD-Access', 'How does BGP choose its best path?'];
  }

  Widget _chatView() {
    return Column(children: [
      if (widget.contextText != null)
        Container(
          width: double.infinity,
          color: AppColors.tint,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(_t('Asking about the question you just answered.', 'Đang hỏi về câu hỏi bạn vừa làm.'),
              style: const TextStyle(fontSize: 13, color: AppColors.primaryShadow, fontWeight: FontWeight.w700)),
        ),
      Expanded(
        child: _msgs.isEmpty
            ? ListView(padding: const EdgeInsets.all(20), children: [
                const SizedBox(height: 10),
                Center(child: SizedBox(width: 130, height: 130, child: Image.asset('assets/mascot/moods/duck_cool.png'))),
                const SizedBox(height: 10),
                Center(
                  child: Text(_t('Ask me anything about ENCOR!', 'Hỏi mình bất cứ điều gì về ENCOR nhé!'),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
                ),
                const SizedBox(height: 16),
                for (final s in _suggestions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PressScale(
                      onTap: () => _send(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.line, width: 2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(s, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
                      ),
                    ),
                  ),
              ])
            : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                itemCount: _msgs.length + (_busy ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= _msgs.length) return _bubble(null, typing: true);
                  return _bubble(_msgs[i]);
                },
              ),
      ),
      Divider(height: 1, color: AppColors.line),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              decoration: InputDecoration(
                hintText: _t('Type your question...', 'Nhập câu hỏi...'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.send_rounded, color: Colors.white),
            onPressed: _busy ? null : () => _send(_input.text),
          ),
        ]),
      ),
    ]);
  }

  Widget _bubble(AiMsg? m, {bool typing = false}) {
    final mine = m?.user ?? false;
    final err = m?.error ?? false;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : (err ? AppColors.errorTint : AppColors.soft),
          borderRadius: BorderRadius.circular(16),
        ),
        child: typing
            ? const SizedBox(width: 36, height: 18, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))))
            : SelectableText(
                mine ? m!.text : _clean(m!.text),
                style: TextStyle(
                    fontSize: 15, height: 1.4, color: mine ? Colors.white : (err ? AppColors.errorShadow : AppColors.ink)),
              ),
      ),
    );
  }
}
