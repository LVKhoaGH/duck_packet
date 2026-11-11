import 'dart:math';
import 'package:flutter/material.dart' hide Text;
import 'i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'bag.dart';
import 'bag_screen.dart';
import 'duck.dart';
import 'extras.dart';
import 'game_session_screen.dart';
import 'history.dart';
import 'library.dart';
import 'library_screen.dart';
import 'learn_tab.dart';
import 'models.dart';
import 'practice_tab.dart';
import 'providers.dart';
import 'reminders.dart';
import 'sfx.dart';
import 'study.dart';
import 'tabs.dart';
import 'theme.dart';
import 'widgets.dart';
import 'duck_mood.dart';
import 'ai_chat.dart';
import 'game_tab.dart';
import 'widget_sync.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 1; // 0 Learn, 1 Map, 2 Practice, 3 Profile
  final PageController _pc = PageController(initialPage: 1);
  final GlobalKey _pagesKey = GlobalKey(); // keeps tab state when the layout switches phone <-> wide

  @override
  void initState() {
    super.initState();
    ref.listenManual(statsProvider, (prev, next) => syncHomeWidget(ref));
    ref.listenManual(statsProvider, (prev, next) => ref.read(reminderProvider.notifier).sync());
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(reminderProvider.notifier).sync());
    ref.listenManual(studyProvider, (prev, next) => syncHomeWidget(ref));
    ref.listenManual(courseProvider, (prev, next) => syncHomeWidget(ref));
    WidgetsBinding.instance.addPostFrameCallback((_) => syncHomeWidget(ref));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = Hive.box('stats');
      final used = (box.get('x_freezeUsed', defaultValue: 0) as num).toInt();
      if (used > 0 && mounted) {
        box.delete('x_freezeUsed');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(used == 1 ? 'Streak Freeze used. Your streak is safe!' : 'Streak Freezes used. Your streak is safe!')));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showWelcomeIfNeeded(context);
   });
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _goTab(int i) {
    Sfx.play('tap');
    if (i == _tab) return;
    if ((i - _tab).abs() > 1) {
      _pc.jumpToPage(i);
    } else {
      _pc.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _openLibrary() => Navigator.push(context, slideUpRoute(const LibraryScreen()));

  Widget _pages(AsyncValue<Course?> courseAsync, Course? course) => KeyedSubtree(
        key: _pagesKey,
        child: PageView(
          controller: _pc,
          onPageChanged: (i) => setState(() => _tab = i),
          children: [
            _KeepAlive(child: LearnTab(course: course, onGoMap: () => _goTab(1))),
            _KeepAlive(
              child: courseAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (c) => c == null ? _EmptyState(onImport: _openLibrary) : _MapView(course: c),
              ),
            ),
            _KeepAlive(child: PracticeTab(course: course)),
            const _KeepAlive(child: GameTab()),
            _KeepAlive(child: ProfileTab(course: course, onImport: _openLibrary)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final courseAsync = ref.watch(courseProvider);
    final stats = ref.watch(statsProvider);
    final course = courseAsync.valueOrNull;
    final label = course?.id.split('_').first.toUpperCase() ?? 'DUCK';

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 800;
      if (!wide) {
        // Phone / portrait: top bar, swipeable tabs, bottom navigation.
        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(fit: StackFit.expand, children: [
            SafeArea(
              bottom: false,
              child: Column(children: [
                _TopBar(label: label, stats: stats),
                Expanded(child: _pages(courseAsync, course)),
              ]),
            ),
            const AiFab(),
          ]),
          bottomNavigationBar: _BottomNav(index: _tab, onTap: _goTab),
        );
      }
      // Laptop / landscape: side rail on the left, content centred (max 760 px).
      return Scaffold(
        backgroundColor: Colors.white,
        body: Stack(fit: StackFit.expand, children: [
          SafeArea(
          child: Row(children: [
            _SideNav(index: _tab, onTap: _goTab),
            Container(width: 2, color: AppColors.line),
            Expanded(
              child: Column(children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _TopBar(label: label, stats: stats),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: _pages(courseAsync, course)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
          const AiFab(right: 24, bottom: 24),
        ]),
      );
    });
  }
}

/// Navigation rail used on wide windows (laptop). Same four tabs as the bottom bar.
class _SideNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _SideNav({required this.index, required this.onTap});

  static const _icons = [Icons.menu_book_rounded, Icons.map_rounded, Icons.fitness_center_rounded, Icons.sports_esports_rounded, Icons.person_rounded];
  static const _labels = ['Learn', 'Map', 'Practice', 'Game', 'Profile'];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 8, 18),
          child: Text('DuckPacket', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ),
        for (var i = 0; i < _labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: i == index ? AppColors.tint : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: i == index ? AppColors.primary : Colors.transparent, width: 2),
                ),
                child: Row(children: [
                  Icon(_icons[i], size: 28, color: i == index ? AppColors.primary : AppColors.locked),
                  const SizedBox(width: 12),
                  Text(_labels[i],
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: i == index ? AppColors.primary : AppColors.lockedShadow)),
                ]),
              ),
            ),
          ),
        const Spacer(),
        const Center(child: DuckView(size: 96)),
      ]),
    );
  }
}

/// Keeps a tab (and its scroll position) alive inside the PageView.
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});
  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _TopBar extends ConsumerWidget {
  final String label;
  final UserStats stats;
  const _TopBar({required this.label, required this.stats});

  Widget _stat(Widget icon, int v, Color c, {bool dim = false}) => AnimatedOpacity(
        opacity: dim ? 0.45 : 1,
        duration: const Duration(milliseconds: 300),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          icon,
          const SizedBox(width: 4),
          AnimatedCount(v, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 17)),
        ]),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bag = ref.watch(bagProvider);
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.line, width: 2))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: duoCard(border: AppColors.secondary, radius: 12),
          child: Text(label, style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w700)),
        ),
        const Spacer(),
        if (bag.boost > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFFFF3D6), borderRadius: BorderRadius.circular(10)),
            child: Text('x2 · ${bag.boost}', style: const TextStyle(color: AppColors.streakShadow, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const SizedBox(width: 10),
        ],
        if (bag.freeze > 0) ...[
          _stat(const Icon(Icons.ac_unit_rounded, size: 22, color: AppColors.primary), bag.freeze, AppColors.primary),
          const SizedBox(width: 12),
        ],
        _stat(const SvgIcon('ic_fire', size: 26), stats.streak, AppColors.streak, dim: !stats.practicedToday),
        const SizedBox(width: 14),
        _stat(const Icon(Icons.bolt_rounded, size: 28, color: AppColors.primary), stats.xp, AppColors.primary),
      ]),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});
  static const _icons = [Icons.menu_book_rounded, Icons.map_rounded, Icons.fitness_center_rounded, Icons.sports_esports_rounded, Icons.person_rounded];

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line, width: 2))),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(children: [
              for (var i = 0; i < _icons.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 64,
                        height: 48,
                        decoration: BoxDecoration(
                          color: i == index ? AppColors.tint : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: i == index ? AppColors.primary : Colors.transparent, width: 2),
                        ),
                        child: Icon(_icons[i], size: 30, color: i == index ? AppColors.primary : const Color(0xFFAFAFAF)),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onImport;
  const _EmptyState({required this.onImport});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const DuckView(size: 150, mood: DuckMood.happy),
            const SizedBox(height: 16),
            const Text('Welcome to DuckPacket!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 6),
            const Text('Add one or more course JSON files to start',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            SizedBox(width: 240, child: Button3D(label: 'Add JSON files', onPressed: onImport)),
          ]),
        ),
      );
}

// ───────────────────────── Map: monsters + bosses ─────────────────────────
double _dx(int i) => sin(i * 1.1) * 64;

IconData _nodeIcon(String file) {
  switch (file.replaceAll('.svg', '')) {
    case 'router':
      return Icons.router_rounded;
    case 'switch_l2':
    case 'switch_l3':
      return Icons.hub_rounded;
    case 'firewall':
      return Icons.security_rounded;
    case 'cloud':
      return Icons.cloud_rounded;
    case 'terminal':
      return Icons.terminal_rounded;
    default:
      return Icons.bug_report_rounded;
  }
}

class _MapView extends ConsumerStatefulWidget {
  final Course course;
  const _MapView({required this.course});
  @override
  ConsumerState<_MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<_MapView> {
  Course get course => widget.course;
  final ScrollController _sc = ScrollController();
  final GlobalKey _curKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _toCurrent(animate: false));
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  void _toCurrent({bool animate = true}) {
    final ctx = _curKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        alignment: 0.35,
        duration: animate ? const Duration(milliseconds: 450) : Duration.zero,
        curve: Curves.easeOutCubic);
  }

  Widget _pill() => Positioned(
        left: 16,
        right: 16,
        bottom: 12,
        child: Center(
          child: PressScale(
            scale: 0.97,
            onTap: () {
              Sfx.play('tap');
              _toCurrent();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: AppColors.primaryShadow, offset: Offset(0, 4))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Current stage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      );

  void _snack(BuildContext c, String t) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(t), duration: const Duration(seconds: 2)));

  void _openNode(BuildContext context, CourseNode node) =>
      Navigator.push(context, slideUpRoute(GameSessionScreen(node: node)));

  void _openBoss(BuildContext context, Chapter ch) {
    // Boss không bốc câu lab (lab cần terminal, không hợp với nhịp 10 câu nhanh).
    final all = <Question>[for (final n in ch.nodes) ...n.questions];
    final noLab = all.where((q) => q.type != 'lab').toList();
    final pool = (noLab.isNotEmpty ? noLab : all)..shuffle();
    if (pool.isEmpty) {
      _snack(context, 'This chapter has no questions yet');
      return;
    }
    final node = CourseNode(id: bossId(ch), title: ch.title, icon: 'router.svg', questions: pool.take(10).toList());
    Navigator.push(context, slideUpRoute(GameSessionScreen(node: node, mode: SessionMode.boss)));
  }

  Future<void> _openChest(BuildContext context, WidgetRef ref, Chapter ch) async {
    final r = ref.read(bagProvider.notifier).openChest(ch.id);
    if (r == null) return;
    Sfx.play('success');
    ref.read(statsProvider.notifier).addXp(r.xp);
    ref.read(extrasProvider.notifier).addXp(r.xp);
    ref.read(historyProvider.notifier).addXp(r.xp);
    await showChestDialog(context, r);
    final gotItem = ref.read(duckProvider.notifier).awardForChapter(ch.id);
    if (gotItem != null && context.mounted) await showDuckUnlock(context, ref, gotItem);
  }

  void _guide(BuildContext context, Chapter ch, Set<String> done, Map<String, int> best) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ch.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 8),
              for (final n in ch.nodes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(done.contains(n.id) ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: done.contains(n.id) ? AppColors.success : AppColors.locked),
                  title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${n.questions.length} questions'),
                  trailing: best[n.id] == null
                      ? null
                      : Text('${best[n.id]}%', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(done.contains(bossId(ch)) ? Icons.emoji_events_rounded : Icons.whatshot_rounded,
                    color: done.contains(bossId(ch)) ? AppColors.streak : AppColors.error),
                title: const Text('Boss', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('10 mixed questions · need $kBossPass%'),
                trailing: best[bossId(ch)] == null
                    ? null
                    : Text('${best[bossId(ch)]}%', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _withMascot(Widget row, double dx, bool current) {
    if (!current) return row;
    return Stack(clipBehavior: Clip.none, children: [
      row,
      Positioned(
        left: dx >= 0 ? 4 : null,
        right: dx < 0 ? 4 : null,
        top: 52,
        child: MascotTip(bubbleRight: dx < 0),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final done = ref.watch(statsProvider).completed;
    final best = ref.watch(studyProvider).best;
    final chests = ref.watch(bagProvider).chests;
    final stages = stageIds(course);
    // First stage of every chapter is open; inside a chapter: in order.
    final unlocked = <String>{};
    for (final ch in course.chapters) {
      if (ch.nodes.isEmpty) continue;
      final seq = [for (final n in ch.nodes) n.id, bossId(ch)];
      for (var i = 0; i < seq.length; i++) {
        if (i == 0 || done.contains(seq[i - 1])) unlocked.add(seq[i]);
      }
    }
    String? currentId;
    for (final s in stages) {
      if (!done.contains(s)) {
        currentId = s;
        break;
      }
    }
    final cleared = stages.where(done.contains).length;

    final slivers = <Widget>[SliverToBoxAdapter(child: _Overall(cleared: cleared, total: stages.length))];
    var k = 0;
    var section = 0;
    for (final ch in course.chapters) {
      if (ch.nodes.isEmpty) continue;
      section++;
      final nodesDone = ch.nodes.where((n) => done.contains(n.id)).length;
      final bossDone = done.contains(bossId(ch));
      final rows = <Widget>[const SizedBox(height: 16)];

      for (final node in ch.nodes) {
        final dx = _dx(k);
        final nextDx = _dx(k + 1);
        final isDone = done.contains(node.id);
        final isUnlocked = unlocked.contains(node.id);
        final isCurrent = node.id == currentId;
        final row = Pop(
          delay: min(k, 8) * 60,
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: Center(
              child: _NodeButton(
                title: node.title,
                icon: _nodeIcon(node.icon),
                pct: best[node.id],
                done: isDone,
                unlocked: isUnlocked,
                current: isCurrent,
                onTap: () => isUnlocked ? _openNode(context, node) : _snack(context, 'Defeat the previous stage first'),
              ),
            ),
          ),
        );
        final withM = _withMascot(row, dx, isCurrent);
        rows.add(isCurrent ? KeyedSubtree(key: _curKey, child: withM) : withM);
        rows.add(_Connector(fromDx: dx, toDx: nextDx, active: isDone));
        k++;
      }

      // boss at the end of the chapter
      final bid = bossId(ch);
      final bdx = _dx(k);
      final bDone = done.contains(bid);
      final bUnlocked = unlocked.contains(bid);
      final bCurrent = bid == currentId;
      final bossRow = Pop(
        delay: min(k, 8) * 60,
        child: Transform.translate(
          offset: Offset(bdx, 0),
          child: Center(
            child: _NodeButton(
              title: 'Boss: ${ch.title}',
              icon: Icons.whatshot_rounded,
              pct: best[bid],
              done: bDone,
              unlocked: bUnlocked,
              current: bCurrent,
              boss: true,
              onTap: () => bUnlocked ? _openBoss(context, ch) : _snack(context, 'Defeat every monster in this section first'),
            ),
          ),
        ),
      );
      final bossM = _withMascot(bossRow, bdx, bCurrent);
      rows.add(bCurrent ? KeyedSubtree(key: _curKey, child: bossM) : bossM);
      k++;

      // chest: appears after the boss, opens once
      final cdx = _dx(k);
      final opened = chests.contains(ch.id);
      rows.add(_Connector(fromDx: bdx, toDx: cdx, active: bDone));
      rows.add(Transform.translate(
        offset: Offset(cdx, 0),
        child: Center(
          child: _ChestButton(
            ready: bDone && !opened,
            opened: opened,
            onTap: () {
              if (bDone && !opened) {
                _openChest(context, ref, ch);
              } else if (!bDone) {
                _snack(context, 'Defeat the boss to unlock this chest');
              }
            },
          ),
        ),
      ));
      rows.add(const SizedBox(height: 36));
      k++;

      slivers.add(SliverMainAxisGroup(slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _UnitHeader(
            section: section,
            title: ch.title,
            done: nodesDone + (bossDone ? 1 : 0),
            total: ch.nodes.length + 1,
            onGuide: () => _guide(context, ch, done, best),
          ),
        ),
        SliverToBoxAdapter(child: Column(children: rows)),
      ]));
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 100)));
    return Stack(children: [
      CustomScrollView(controller: _sc, slivers: slivers),
      if (currentId != null) _pill(),
    ]);
  }
}

class _Overall extends StatelessWidget {
  final int cleared, total;
  const _Overall({required this.cleared, required this.total});
  @override
  Widget build(BuildContext context) {
    final v = total == 0 ? 0.0 : cleared / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: duoCard(border: AppColors.line),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.flag_rounded, color: AppColors.streak),
            const SizedBox(width: 8),
            const Text('Course cleared', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const Spacer(),
            Text('${(v * 100).round()}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.success)),
          ]),
          const SizedBox(height: 10),
          ProgressBar3D(v, track: AppColors.line),
          const SizedBox(height: 6),
          Text('$cleared / $total stages (monsters + bosses)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45)),
        ]),
      ),
    );
  }
}

class _UnitHeader extends SliverPersistentHeaderDelegate {
  final int section, done, total;
  final String title;
  final VoidCallback onGuide;
  _UnitHeader({required this.section, required this.title, required this.done, required this.total, required this.onGuide});

  @override
  double get minExtent => 92;
  @override
  double get maxExtent => 92;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: AppColors.primaryShadow, offset: Offset(0, 4))],
          ),
          child: Row(children: [
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SECTION $section  ·  $done/$total',
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
              ]),
            ),
            GestureDetector(
              onTap: onGuide,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white54, width: 2),
                ),
                child: const Icon(Icons.list_alt_rounded, color: Colors.white),
              ),
            ),
          ]),
        ),
      );

  @override
  bool shouldRebuild(covariant _UnitHeader old) => old.done != done || old.title != title || old.total != total;
}

class _NodeButton extends StatefulWidget {
  final String title;
  final IconData icon;
  final int? pct;
  final bool done, unlocked, current, boss;
  final VoidCallback onTap;
  const _NodeButton({
    required this.title,
    required this.icon,
    required this.pct,
    required this.done,
    required this.unlocked,
    required this.current,
    required this.onTap,
    this.boss = false,
  });
  @override
  State<_NodeButton> createState() => _NodeButtonState();
}

class _NodeButtonState extends State<_NodeButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final Color color;
    final Color shadow;
    if (!w.unlocked) {
      color = AppColors.locked;
      shadow = AppColors.lockedShadow;
    } else if (w.boss) {
      color = w.done ? AppColors.streak : AppColors.error;
      shadow = w.done ? AppColors.streakShadow : AppColors.errorShadow;
    } else {
      color = w.done ? AppColors.success : AppColors.primary;
      shadow = w.done ? AppColors.successShadow : AppColors.primaryShadow;
    }
    final bw = w.boss ? 98.0 : 80.0, bh = w.boss ? 90.0 : 76.0;
    final IconData ic = !w.unlocked ? Icons.lock_rounded : (w.boss && w.done ? Icons.emoji_events_rounded : w.icon);

    final circle = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: bw,
      height: bh,
      margin: EdgeInsets.only(top: _down ? 6 : 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.22)!, color],
        ),
        borderRadius: BorderRadius.circular(bh / 2),
        boxShadow: [BoxShadow(color: shadow, offset: Offset(0, _down ? 0 : 6))],
      ),
      child: Icon(ic, size: w.boss ? 48 : 36, color: Colors.white),
    );

    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        height: w.current ? 46 : 0,
        child: w.current
            ? Bobbing(
                amplitude: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: duoCard(border: AppColors.line, radius: 12),
                  child: Text(w.boss ? 'FIGHT!' : 'START',
                      style: TextStyle(color: w.boss ? AppColors.error : AppColors.primary, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                ),
              )
            : null,
      ),
      GestureDetector(
        onTapDown: w.unlocked ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          if (w.unlocked) Sfx.play('tap');
          w.onTap();
        },
        child: SizedBox(
          width: bw + 6,
          height: bh + 10,
          child: Stack(alignment: Alignment.topCenter, clipBehavior: Clip.none, children: [
            w.current ? PulseRing(size: bh, color: color, child: circle) : circle,
            if (w.done)
              Positioned(
                right: 2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: AppColors.streak, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  child: const Icon(Icons.star_rounded, size: 16, color: Colors.white),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 4),
      SizedBox(
        width: 170,
        child: Text(w.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, color: w.unlocked ? AppColors.ink : AppColors.lockedShadow)),
      ),
      if (w.pct != null) ...[
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: (w.pct! >= kBossPass ? AppColors.success : AppColors.streak).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('Best ${w.pct}%',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: w.pct! >= kBossPass ? AppColors.successShadow : AppColors.streakShadow)),
        ),
      ],
    ]);
  }
}

/// Dashed S-curve joining one stage to the next.
class _Connector extends StatelessWidget {
  final double fromDx, toDx;
  final bool active;
  const _Connector({required this.fromDx, required this.toDx, required this.active});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 40,
        child: CustomPaint(
          painter: _ConnectorPainter(fromDx, toDx, active ? AppColors.success.withOpacity(0.55) : AppColors.line),
        ),
      );
}

class _ConnectorPainter extends CustomPainter {
  final double fromDx, toDx;
  final Color color;
  _ConnectorPainter(this.fromDx, this.toDx, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final path = Path()
      ..moveTo(cx + fromDx, 0)
      ..cubicTo(cx + fromDx, size.height * 0.55, cx + toDx, size.height * 0.45, cx + toDx, size.height);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 7), paint);
        d += 15;
      }
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) => old.fromDx != fromDx || old.toDx != toDx || old.color != color;
}

class _ChestButton extends StatelessWidget {
  final bool ready, opened;
  final VoidCallback onTap;
  const _ChestButton({required this.ready, required this.opened, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = ready ? AppColors.streak : (opened ? AppColors.success : AppColors.locked);
    final shadow = ready ? AppColors.streakShadow : (opened ? AppColors.successShadow : AppColors.lockedShadow);
    final box = Container(
      width: 80,
      height: 66,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(color, Colors.white, 0.22)!, color]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: shadow, offset: const Offset(0, 6))],
      ),
      child: Icon(opened ? Icons.check_rounded : (ready ? Icons.card_giftcard_rounded : Icons.lock_rounded), size: 38, color: Colors.white),
    );
    return GestureDetector(
      onTap: () {
        if (ready) Sfx.play('tap');
        onTap();
      },
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ready ? Bobbing(amplitude: 4, child: box) : box,
        const SizedBox(height: 10),
        Text(ready ? 'Tap to open!' : (opened ? 'Opened' : 'Chest'),
            style: TextStyle(fontWeight: FontWeight.w700, color: ready ? AppColors.streakShadow : AppColors.lockedShadow)),
      ]),
    );
  }
}
