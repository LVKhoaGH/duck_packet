DuckPacket v8 - Nhieu khoa hoc (ENCOR / CCBA / Custom) + mock exam theo khoa (giai nen de len duck_packet/)

FILE MOI:   lib/tracks.dart, assets/courses/encor/README.txt, assets/courses/ccba/ccba_sample.json
FILE DE:    lib/main.dart, lib/settings_screen.dart, lib/study.dart, lib/exam_screen.dart, pubspec.yaml
KHONG DOI:  library.dart, home_screen.dart, practice_tab.dart (practice_tab/exam_screen cua v6 da co san)

CACH HOAT DONG
- Lan dau mo app: chon CCNP ENCOR / CCBA / Custom. Settings > Course de doi khoa.
- XP, streak, vit, do dung chung. Tien do bai hoc/cau sai tach theo khoa vi id khac nhau.
- ENCOR, CCBA: lay JSON dong goi trong assets/courses/<khoa>/*.json (moi file .json gop thanh 1 khoa).
- Custom: nhu cu, tu import JSON (cac file ban da import truoc day nam o Custom).
- Mock exam: ENCOR 100 cau/120 phut; CCBA 130 cau/180 phut, chi lay cau multiple_choice; dau khi >= 82.5%.
- CCBA: ten chapter phai bat dau bang ma domain: RADD / EC / RLCM / BAPM / SA / SE (vd "RADD – Requirements Analysis...").
  Ty trong: RADD 32, EC 20, RLCM 18, BAPM 12, SA 12, SE 6.

VIEC BAN CAN LAM
- Bo cac file JSON ENCOR that vao assets/courses/encor/ (hien chi co README). Chua co thi ENCOR bao "No lessons bundled yet".
- Thay ccba_sample.json bang file CCBA that (sample chi co 6 cau de test).
- Sau khi them asset: flutter pub get, dung han app roi chay lai.
Chua bien dich.
