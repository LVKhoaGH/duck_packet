// i18n_vi_meta.dart  (FILE MỚI)  Bản dịch tiếng Việt cho nhiệm vụ / huy hiệu / thưởng bất ngờ.
// tr() tra kVi (i18n_vi.dart) trước, rồi tra bảng này.
import 'i18n_vi.dart' show ViRule;

const Map<String, String> kViMeta = {
  'Quests': 'Nhiệm vụ',
  'Badges': 'Huy hiệu',
  'Daily quests': 'Nhiệm vụ hằng ngày',
  'Claim': 'Nhận',
  'Claim reward!': 'Nhận thưởng!',
  'Awesome!': 'Tuyệt vời!',
  'Quest complete!': 'Hoàn thành nhiệm vụ!',
  'Claim quest rewards in Profile → Quests.': 'Nhận thưởng nhiệm vụ ở Hồ sơ → Nhiệm vụ.',
  'New badge!': 'Huy hiệu mới!',
  'Nice work!': 'Làm tốt lắm!',
  'Surprise reward!': 'Phần thưởng bất ngờ!',
  'JACKPOT!': 'TRÚNG LỚN!',
  'A new duck item!': 'Một món đồ mới cho vịt!',
  'All quests done!': 'Xong hết nhiệm vụ!',
  'Daily bonus': 'Thưởng ngày',
  'Daily bonus!': 'Thưởng ngày!',
  'Daily bonus claimed': 'Đã nhận thưởng ngày',
  'Reward claimed!': 'Đã nhận thưởng!',
  'New quests every day. Finish all 3 for a bonus!': 'Mỗi ngày có nhiệm vụ mới. Xong cả 3 để nhận thưởng thêm!',
  'Days completed': 'Ngày hoàn thành',
  'Rewards claimed': 'Thưởng đã nhận',
  'Learning': 'Học tập',
  'Speed': 'Tốc độ',
  'Grit': 'Bền bỉ',
  'Streaks': 'Chuỗi ngày',
  'Bosses': 'Trùm',
  'Labs': 'Lab',
  'Luck': 'May mắn',
  'Collection': 'Sưu tập',
  'Study reminders': 'Nhắc học',
  'Remind me at': 'Nhắc tôi lúc',
  'Warn me before I lose my streak': 'Cảnh báo trước khi mất chuỗi ngày',
  'Send a test notification': 'Gửi thông báo thử',
  'Notifications are blocked. Allow them in your browser or phone settings.': 'Thông báo đang bị chặn. Hãy cho phép trong trình duyệt hoặc cài đặt điện thoại.',
  'Reminders on Android and iPhone work even when the app is closed. On web and Windows the app must stay open.': 'Trên Android và iPhone, nhắc học hoạt động cả khi đóng app. Trên web và Windows, app phải còn mở.',
};

final List<ViRule> kViMetaRules = [
  ViRule(RegExp(r'^(\d+)/(\d+) done$'), (m) => '${m[1]}/${m[2]} xong'),
  ViRule(RegExp(r'^(\d+)/(\d+) unlocked$'), (m) => 'Mở ${m[1]}/${m[2]}'),
  ViRule(RegExp(r'^Daily bonus: \+(\d+) XP and a free item when all 3 are claimed$'),
      (m) => 'Thưởng ngày: +${m[1]} XP và một vật phẩm khi nhận đủ cả 3'),
];
