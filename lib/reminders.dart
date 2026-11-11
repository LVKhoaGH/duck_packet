// reminders.dart  (FILE MỚI)  Nhắc học hằng ngày + nhắc "sắp mất streak".
//  Android / iOS : hẹn sẵn 7 ngày tới trong hệ điều hành, nhắc được cả khi app đóng.
//                  Mỗi lần mở app hoặc học xong một bài, lịch được tính lại (học xong rồi thì hôm nay không nhắc nữa).
//  Web / Windows : app tự kiểm tra giờ mỗi 30 giây, nên app phải còn mở (tab trình duyệt / cửa sổ app, thu nhỏ vẫn được).
// Hive (box 'stats'): x_remOn, x_remMin (phút từ 0h, mặc định 20:00), x_remRescue, x_remShown.
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'i18n.dart' show AppLang;
import 'providers.dart';
import 'reminder_backend_web.dart' if (dart.library.io) 'reminder_backend_native.dart';

const int kRescueMinutes = 21 * 60 + 30; // 21:30

class ReminderState {
  final bool enabled, rescue;
  final int minutes; // giờ nhắc chính, tính bằng phút từ 0h
  const ReminderState({this.enabled = false, this.rescue = true, this.minutes = 20 * 60});
  ReminderState copy({bool? enabled, bool? rescue, int? minutes}) =>
      ReminderState(enabled: enabled ?? this.enabled, rescue: rescue ?? this.rescue, minutes: minutes ?? this.minutes);
  int get hour => minutes ~/ 60;
  int get minute => minutes % 60;
}

const _mainEn = [
  ['Quack! Time to study', 'One short lesson keeps your duck happy.'],
  ['Your duck misses you', 'Come back for a quick quiz.'],
  ['Packets will not route themselves', 'Open DuckPacket and learn something new.'],
  ['Daily quests are waiting', 'Finish them and grab the daily bonus.'],
  ['A surprise reward might be waiting', 'Finish one lesson to find out.'],
  ['Ten minutes today beats ten hours later', 'Let us do a lesson together.'],
];
const _mainVi = [
  ['Quạc! Đến giờ học rồi', 'Một bài ngắn thôi là vịt vui cả ngày.'],
  ['Vịt nhớ bạn lắm', 'Quay lại làm vài câu nhé.'],
  ['Gói tin không tự định tuyến đâu', 'Mở DuckPacket và học điều mới nào.'],
  ['Nhiệm vụ hằng ngày đang chờ', 'Làm xong để nhận thưởng ngày.'],
  ['Biết đâu có phần thưởng bất ngờ', 'Làm một bài để biết nhé.'],
  ['Hôm nay 10 phút hơn sau này 10 giờ', 'Học với vịt một bài nào.'],
];

List<String> _mainMsg(int i) => (AppLang.vi ? _mainVi : _mainEn)[i % _mainEn.length];

List<String> _rescueMsg(int streak) => AppLang.vi
    ? ['Chuỗi $streak ngày sắp mất!', 'Học nhanh một bài để giữ chuỗi nhé.']
    : ['Your $streak-day streak ends tonight!', 'One quick lesson keeps it alive.'];

class ReminderNotifier extends Notifier<ReminderState> {
  Box get _box => Hive.box('stats');
  Timer? _timer;
  bool _busy = false, _again = false;

  @override
  ReminderState build() {
    ref.onDispose(() => _timer?.cancel());
    return ReminderState(
      enabled: _box.get('x_remOn') == true,
      rescue: _box.get('x_remRescue') != false,
      minutes: ((_box.get('x_remMin') as num?) ?? 20 * 60).toInt(),
    );
  }

  /// Bật cần được phép thông báo. Trả về false nếu bị từ chối (công tắc vẫn tắt).
  Future<bool> setEnabled(bool v) async {
    if (v) {
      final ok = await ReminderBackend.requestPermission();
      if (!ok) return false;
    }
    _box.put('x_remOn', v);
    state = state.copy(enabled: v);
    if (v) _markPassed();
    await sync();
    return true;
  }

  Future<void> setMinutes(int m) async {
    _box.put('x_remMin', m);
    state = state.copy(minutes: m);
    _markPassed();
    await sync();
  }

  Future<void> setRescue(bool v) async {
    _box.put('x_remRescue', v);
    state = state.copy(rescue: v);
    await sync();
  }

  Future<void> testNow() async {
    final m = _mainMsg(0);
    await ReminderBackend.showNow(m[0], m[1]);
  }

  /// Giờ đã qua lúc vừa bật / đổi giờ thì hôm nay không nhắc bù (chỉ ảnh hưởng web / Windows).
  void _markPassed() {
    final now = DateTime.now();
    final today = dayKey(now);
    final cur = now.hour * 60 + now.minute;
    final shown = <String>{...('${_box.get('x_remShown', defaultValue: '')}').split(',').where((e) => e.isNotEmpty)};
    shown.removeWhere((e) => !e.startsWith(today));
    if (cur >= state.minutes) shown.add('$today:m');
    if (cur >= kRescueMinutes) shown.add('$today:r');
    _box.put('x_remShown', shown.join(','));
  }

  /// Tính lại lịch. Gọi lúc mở app, sau mỗi bài học và khi đổi cài đặt.
  Future<void> sync() async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        await _syncOnce();
      } while (_again);
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  Future<void> _syncOnce() async {
    _timer?.cancel();
    _timer = null;
    final s = state;
    if (!s.enabled) {
      await ReminderBackend.cancelAll();
      return;
    }
    await ReminderBackend.init();
    if (!ReminderBackend.canSchedule) {
      // web / Windows: app tự canh giờ khi đang mở
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
      return;
    }
    await ReminderBackend.cancelAll();
    final stats = ref.read(statsProvider);
    final now = DateTime.now();
    final doneToday = stats.practicedToday;
    final streakAlive = stats.streak > 0;
    for (var d = 0; d < 7; d++) {
      final main = DateTime(now.year, now.month, now.day + d, s.hour, s.minute);
      final skip = d == 0 && doneToday;
      final msg = _mainMsg(dayNum0(now) + d);
      if (!skip && main.isAfter(now)) await ReminderBackend.schedule(100 + d * 2, main, msg[0], msg[1]);
      if (s.rescue && streakAlive && d <= 1 && !skip) {
        var rt = DateTime(now.year, now.month, now.day + d, kRescueMinutes ~/ 60, kRescueMinutes % 60);
        final minRescue = main.add(const Duration(minutes: 60));
        if (rt.isBefore(minRescue)) rt = minRescue;
        if (rt.day == main.day && rt.hour < 23 && rt.isAfter(now)) {
          final r = _rescueMsg(stats.streak);
          await ReminderBackend.schedule(101 + d * 2, rt, r[0], r[1]);
        }
      }
    }
  }

  int dayNum0(DateTime n) => DateTime.utc(n.year, n.month, n.day).millisecondsSinceEpoch ~/ 86400000;

  /// Web / Windows: kiểm tra mỗi 30 giây.
  void _tick() {
    final s = state;
    if (!s.enabled) return;
    final stats = ref.read(statsProvider);
    if (stats.practicedToday) return;
    final now = DateTime.now();
    final today = dayKey(now);
    final cur = now.hour * 60 + now.minute;
    final shown = <String>{...('${_box.get('x_remShown', defaultValue: '')}').split(',').where((e) => e.isNotEmpty)};
    shown.removeWhere((e) => !e.startsWith(today));
    if (cur >= s.minutes && cur < s.minutes + 180 && !shown.contains('$today:m')) {
      shown.add('$today:m');
      final m = _mainMsg(dayNum0(now));
      ReminderBackend.showNow(m[0], m[1]);
    } else if (s.rescue &&
        stats.streak > 0 &&
        cur >= kRescueMinutes &&
        cur < 23 * 60 + 30 &&
        !shown.contains('$today:r')) {
      shown.add('$today:r');
      final r = _rescueMsg(stats.streak);
      ReminderBackend.showNow(r[0], r[1]);
    }
    _box.put('x_remShown', shown.join(','));
  }
}

final reminderProvider = NotifierProvider<ReminderNotifier, ReminderState>(ReminderNotifier.new);
