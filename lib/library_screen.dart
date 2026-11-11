import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'import_service.dart';
import 'library.dart';
import 'sample_course.dart';
import 'sfx.dart';
import 'theme.dart';

/// Add JSON files, group them in folders (long-press a file and drag it onto a folder),
/// switch them on/off, reorder, delete.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  // ───────────────────────── actions ─────────────────────────
  Future<void> _add(BuildContext context, WidgetRef ref, [String folder = '']) async {
    ImportReport? rep;
    try {
      rep = await ref.read(importServiceProvider).importFiles(folder: folder);
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
                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
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

  /// Small name dialog (folder name). Returns null when cancelled or empty.
  Future<String?> _askName(BuildContext context, String title, String initial) async {
    final ctrl = TextEditingController(text: initial);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(hintText: 'Folder name'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('OK')),
        ],
      ),
    );
    if (res == null || res.isEmpty) return null;
    return res;
  }

  Future<void> _newFolder(BuildContext context, WidgetRef ref) async {
    final name = await _askName(context, 'New folder', '');
    if (name == null) return;
    Sfx.play('tap');
    ref.read(foldersProvider.notifier).create(name);
  }

  Future<void> _renameFolder(BuildContext context, WidgetRef ref, PackFolder f) async {
    final name = await _askName(context, 'Rename folder', f.name);
    if (name == null) return;
    ref.read(foldersProvider.notifier).rename(f.id, name);
  }

  Future<void> _deleteFolder(BuildContext context, WidgetRef ref, PackFolder f, int count) async {
    final r = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete folder "${f.name}"?'),
        content: Text(count == 0
            ? 'The folder is empty.'
            : 'It holds $count file(s). Your progress is kept either way. Keep the files (they move out of the folder) or delete them too?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          if (count > 0) TextButton(onPressed: () => Navigator.pop(ctx, 1), child: const Text('KEEP FILES')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 2),
              child: Text(count > 0 ? 'DELETE ALL' : 'DELETE', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (r == null) return;
    Sfx.play('tap');
    final packs = ref.read(packsProvider.notifier);
    if (r == 1) {
      packs.ungroup(f.id);
    } else {
      packs.removeIn(f.id);
    }
    ref.read(foldersProvider.notifier).remove(f.id);
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

  // ───────────────────────── pieces ─────────────────────────
  /// What follows your finger while dragging a file.
  Widget _feedback(Pack p) => Material(
        color: Colors.transparent,
        child: Container(
          width: 240,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: duoCard(border: AppColors.primary),
          child: Row(children: [
            const Icon(Icons.description_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink, decoration: TextDecoration.none)),
            ),
          ]),
        ),
      );

  /// One file. [i]/[n] = position inside its own group (folder or "not in a folder").
  Widget _packCard(BuildContext context, WidgetRef ref, Pack p, int i, int n, List<PackFolder> folders) {
    final c = p.course;
    final on = p.enabled;
    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.success,
            onChanged: (_) {
              Sfx.play('tap');
              ref.read(packsProvider.notifier).toggle(p.id);
            },
          ),
        ]),
        const SizedBox(height: 4),
        Text(
            '${c.chapters.length} chapters · ${p.nodeCount} nodes · ${p.questionCount} questions · ${p.lessonCount} lessons'
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
          if (folders.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Move to folder',
              icon: const Icon(Icons.folder_open_rounded, color: Colors.black45),
              onSelected: (v) {
                Sfx.play('tap');
                ref.read(packsProvider.notifier).moveTo(p.id, v == '_root' ? '' : v);
              },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                if (p.folder.isNotEmpty) const PopupMenuItem<String>(value: '_root', child: Text('Take out of folder')),
                for (final f in folders)
                  if (f.id != p.folder) PopupMenuItem<String>(value: f.id, child: Text(f.name)),
              ],
            ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: () => _delete(context, ref, p),
          ),
        ]),
      ]),
    );
    return LongPressDraggable<String>(
      data: p.id,
      feedback: _feedback(p),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }

  Widget _folderCard(BuildContext context, WidgetRef ref, PackFolder f, List<PackFolder> folders, List<Pack> all) {
    final inside = <Pack>[for (final p in all) if (p.folder == f.id) p];
    final onCount = inside.where((p) => p.enabled).length;
    final allOn = inside.isNotEmpty && onCount == inside.length;
    final fn = ref.read(foldersProvider.notifier);
    return DragTarget<String>(
      onAcceptWithDetails: (d) {
        Sfx.play('tap');
        ref.read(packsProvider.notifier).moveTo(d.data, f.id);
      },
      builder: (ctx, cand, rej) {
        final hot = cand.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: hot ? duoCard(border: AppColors.success, fill: AppColors.tint) : duoCard(border: AppColors.line),
          child: Column(children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Sfx.play('tap');
                fn.toggleOpen(f.id);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                child: Row(children: [
                  Icon(f.open ? Icons.folder_open_rounded : Icons.folder_rounded, color: AppColors.streak, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                      Text('${inside.length} file(s) · $onCount on',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38)),
                    ]),
                  ),
                  Switch(
                    value: allOn,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.success,
                    onChanged: inside.isEmpty
                        ? null
                        : (v) {
                            Sfx.play('tap');
                            ref.read(packsProvider.notifier).setEnabledIn(f.id, v);
                          },
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Folder menu',
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.black45),
                    onSelected: (v) {
                      if (v == 'rename') {
                        _renameFolder(context, ref, f);
                      } else if (v == 'add') {
                        _add(context, ref, f.id);
                      } else if (v == 'up') {
                        fn.move(f.id, -1);
                      } else if (v == 'down') {
                        fn.move(f.id, 1);
                      } else if (v == 'delete') {
                        _deleteFolder(context, ref, f, inside.length);
                      }
                    },
                    itemBuilder: (_) => const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(value: 'add', child: Text('Add files here')),
                      PopupMenuItem<String>(value: 'rename', child: Text('Rename')),
                      PopupMenuItem<String>(value: 'up', child: Text('Move folder up')),
                      PopupMenuItem<String>(value: 'down', child: Text('Move folder down')),
                      PopupMenuItem<String>(value: 'delete', child: Text('Delete folder')),
                    ],
                  ),
                  Icon(f.open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Colors.black38),
                  const SizedBox(width: 6),
                ]),
              ),
            ),
            if (f.open)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                child: Column(children: [
                  if (inside.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 4, 4, 14),
                      child: Text('Empty. Drag a file here, or open the menu and choose "Add files here".',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38)),
                    ),
                  for (var i = 0; i < inside.length; i++) _packCard(context, ref, inside[i], i, inside.length, folders),
                ]),
              ),
          ]),
        );
      },
    );
  }

  Widget _rootSection(BuildContext context, WidgetRef ref, List<Pack> loose, List<PackFolder> folders) {
    if (folders.isEmpty) {
      return Column(children: [
        for (var i = 0; i < loose.length; i++) _packCard(context, ref, loose[i], i, loose.length, folders),
      ]);
    }
    return DragTarget<String>(
      onAcceptWithDetails: (d) {
        Sfx.play('tap');
        ref.read(packsProvider.notifier).moveTo(d.data, '');
      },
      builder: (ctx, cand, rej) {
        final hot = cand.isNotEmpty;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          decoration: BoxDecoration(
            color: hot ? AppColors.tint : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hot ? AppColors.primary : AppColors.line, width: 2),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(6, 2, 6, 8),
              child: Text('NOT IN A FOLDER',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Colors.black38)),
            ),
            if (loose.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(6, 0, 6, 14),
                child: Text('Drop a file here to take it out of its folder.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38)),
              ),
            for (var i = 0; i < loose.length; i++) _packCard(context, ref, loose[i], i, loose.length, folders),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(packsProvider);
    final folders = ref.watch(foldersProvider);
    final ids = <String>{for (final f in folders) f.id};
    final loose = <Pack>[for (final p in packs) if (!ids.contains(p.folder)) p];
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
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _newFolder(context, ref),
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: duoCard(border: AppColors.streak, shadow: AppColors.streakShadow),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.create_new_folder_rounded, color: AppColors.streak),
                    SizedBox(width: 8),
                    Text('NEW FOLDER', style: TextStyle(color: AppColors.streak, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  ]),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                  'Pick several files at once (.json or .zip). Long-press a file and drag it onto a folder, or use the folder icon on the file. '
                  'Chapters follow this order: folders top to bottom, then files not in a folder.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38)),
              const SizedBox(height: 16),
              if (packs.isEmpty && folders.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: duoCard(border: AppColors.line),
                  child: const Column(children: [
                    Icon(Icons.inbox_rounded, size: 44, color: AppColors.locked),
                    SizedBox(height: 8),
                    Text('The library is empty', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    SizedBox(height: 4),
                    Text('Add a JSON file, or open "Sample JSON" to see the format.',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w700)),
                  ]),
                ),
              for (final f in folders) _folderCard(context, ref, f, folders, packs),
              _rootSection(context, ref, loose, folders),
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
