DuckPacket v9 - Sua AI tren Android + build Windows portable (giai nen de len duck_packet/)

FILE:
 android/app/src/main/AndroidManifest.xml   (DE) them quyen INTERNET
 .github/workflows/build-windows.yml        (MOI) build exe portable tren GitHub Actions

1) Android khong goi duoc AI: ban release khong co quyen INTERNET trong manifest chinh
   (chi ban debug tu co), nen "Failed host lookup". Web khong bi. Da them
   <uses-permission android:name="android.permission.INTERNET"/>. Build APK lai va cai de.
2) Windows portable: Actions > "Build Windows portable" > artifact duckpacket-windows
   (DuckPacket-windows.zip). Giai nen ra thu muc bat ky, chay duckpacket.exe. Khong can cai dat/quyen admin.
   Du lieu nam trong Documents cua user. Chua bien dich.
