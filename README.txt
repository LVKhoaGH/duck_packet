v10e (sửa lỗi build; giải nén đè lên bản v10d)
  android/settings.gradle.kts                          AGP 9.1.0 -> 9.1.1 (Flutter mới đòi >= 9.1.1)
  android/gradle/wrapper/gradle-wrapper.properties     Gradle 9.3.1 -> 9.5.0
  .github/workflows/build-apk.yml                      thêm cờ --android-skip-build-dependency-validation (dự phòng)
  .github/workflows/build-windows.yml                  tắt lỗi STL1011 của plugin thông báo Windows (biến môi trường CL)
  lib/reminder_backend_web.dart, lib/home_screen.dart, lib/settings_screen.dart   dọn 5 lint
