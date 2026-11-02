import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'import_service.dart';
import 'library.dart';
import 'sample_course.dart';
import 'sfx.dart';
import 'theme.dart';

/// Add several JSON files, switch them on/off, reorder, delete.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    ImportReport? rep;
    try {
      rep = await ref.read(importServiceProvider).importFiles();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      return;
    }
    if (rep == null || !context.mounted) return;
    final r = rep;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(r.failed.isEmpty ? 'Imported ${r.ok.length} file(s)' : 'Import result'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final f in r.ok)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(f, style: const TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                ),
              for (final f in r.failed)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                  child: SelectableText(f, style: const TextStyle(color: AppColors.error, fontSize: 13, height: 1.35)),
                ),
              if (r.ok.isEmpty && r.failed.isEmpty) const Text('Nothing was imported.'),
            ]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Pack p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove "${p.name}"?'),
        content: const Text('Your progress is kept. Add the file again to bring the chapters back. To hide it only for a while, use the switch instead.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('REMOVE', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) {
      Sfx.play('tap');
      ref.read(packsProvider.notifier).remove(p.id);
    }
  }

  void _sample(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Sample JSON', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 4),
              const Text(
                'One file = one or more chapters. IDs (chapter_id, node_id) must be unique across all files. '
                '"lesson" and "glossary" are optional.',
                style: TextStyle(fontSize: 13, height: 1.35, color: Colors.black54, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: AppColors.terminalBg, borderRadius: BorderRadius.circular(14)),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(kSampleJson, style: codeStyle.copyWith(fontSize: 11.5, height: 1.45)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Button3D(
                label: 'Copy sample JSON',
                onPressed: () async {
                  await Clipboard.setData(const ClipboardData(text: kSampleJson));
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Copied. Paste it into a .json file')));
                  }
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, Pack p, int i, int n) {
    final c = p.course;
    final on = p.enabled;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
      decoration: on ? duoCard(border: AppColors.primary) : duoCard(border: AppColors.line, fill: const Color(0xFFF7F7F7), shadow: AppColors.line),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.description_rounded, color: on ? AppColors.primary : AppColors.locked),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: on ? AppColors.ink : AppColors.lockedShadow)),
              Text(c.chapters.map((x) => x.title).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38)),
            ]),
          ),
          Switch(
            value: on,
            activeColor: Colors.white,
            activeTrackColor: AppColors.success,
            onChanged: (_) {
              Sfx.play('tap');
              ref.read(packsProvider.notifier).toggle(p.id);
            },
          ),
        ]),
        const SizedBox(height: 4),
        Text('${c.chapters.length} chapters · ${p.nodeCount} nodes · ${p.questionCount} questions · ${p.lessonCount} lessons'
            '${c.glossary.isEmpty ? '' : ' · ${c.glossary.length} terms'}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45)),
        Row(children: [
          IconButton(
            tooltip: 'Move up',
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            onPressed: i == 0 ? null : () => ref.read(packsProvider.notifier).move(p.id, -1),
          ),
          IconButton(
            tooltip: 'Move down',
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: i == n - 1 ? null : () => ref.read(packsProvider.notifier).move(p.id, 1),
          ),
          const Spacer(),
          if (!on) const Text('Hidden', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black38)),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: () => _delete(context, ref, p),
          ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(packsProvider);
    final active = packs.where((p) => p.enabled).length;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 4),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 28, color: Color(0xFFAFAFAF)), onPressed: () => Navigator.pop(context)),
              const Expanded(child: Text('Course library', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink))),
              Text('$active/${packs.length} on', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black45)),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              Button3D(label: 'Add JSON files', onPressed: () => _add(context, ref)),
              const SizedBox(height: 6),
              const Text('You can pick several files at once (.json or .zip). Chapters appear in the order of this list.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38)),
              const SizedBox(height: 16),
              if (packs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: duoCard(border: AppColors.line),
                  child: const Column(children: [
                    Icon(Icons.inbox_rounded, size: 44, color: AppColors.locked),
                    SizedBox(height: 8),
                    Text('The library is empty',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    SizedBox(height: 4),
                    Text('Add a JSON file, or open "Sample JSON" to see the format.',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700)),
                  ]),
                ),
              for (var i = 0; i < packs.length; i++) _card(context, ref, packs[i], i, packs.length),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _sample(context),
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: duoCard(border: AppColors.secondary, shadow: AppColors.primaryShadow),
                  child: const Text('SAMPLE JSON',
                      style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
