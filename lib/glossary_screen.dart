import 'package:flutter/material.dart';
import 'models.dart';
import 'theme.dart';

/// Searchable list of terms and commands (from the "glossary" array of the course JSON).
class GlossaryScreen extends StatefulWidget {
  final List<GlossaryItem> items;
  const GlossaryScreen({super.key, required this.items});
  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = widget.items
        .where((g) => q.isEmpty || g.term.toLowerCase().contains(q) || g.def.toLowerCase().contains(q) || g.cmd.toLowerCase().contains(q) || g.tag.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.term.toLowerCase().compareTo(b.term.toLowerCase()));
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 4),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 28, color: Color(0xFFAFAFAF)), onPressed: () => Navigator.pop(context)),
              const Expanded(child: Text('Glossary', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink))),
              Text('${list.length}', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black45)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'Search term or command',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFFF7F7F7),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: widget.items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No glossary in this course yet.\nAdd a "glossary" array to the course JSON.',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _GlossaryCard(g: list[i]),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _GlossaryCard extends StatelessWidget {
  final GlossaryItem g;
  const _GlossaryCard({required this.g});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: duoCard(border: AppColors.line),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(g.term, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primaryShadow))),
            if (g.tag.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.tint, borderRadius: BorderRadius.circular(10)),
                child: Text(g.tag, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryShadow)),
              ),
          ]),
          const SizedBox(height: 4),
          Text(g.def, style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.ink)),
          if (g.cmd.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.terminalBg, borderRadius: BorderRadius.circular(10)),
              child: Text(g.cmd, style: codeStyle.copyWith(fontSize: 13)),
            ),
          ],
        ]),
      );
}
