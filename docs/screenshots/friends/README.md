# 好友畫面截圖

在電腦上用 widget 測試畫出來的，不是手機實拍：假資料（`FakeFriendsRepository.seeded()`），412×915 邏輯像素、2 倍。

- `classic_*`：原本的藍色主題，淺色。
- `classic-dark_*`：同一個主題的深色版（`AppSettings.darkMode` 預設是 true，新安裝看到的是這個）。
- `mascot_*`：粗哥插畫主題（只有淺色）。

掃 QR 的頁面要用相機，沒有截。

## 重新產生

```bash
python -I tool/make_cjk_fonts.py
flutter test tool/friends_screenshots_test.dart
```

`make_cjk_fonts.py` 把 Noto Sans TC 切成 400／500／700 三個固定字重放進 `build/`（不入庫），中文才不會變成細體。測試會在這個資料夾輸出 PNG；入庫前轉成 WebP（品質 80）以免太大。
