"""Tiles the screenshots from tool/app_screenshots_test.dart into the one-sheet
overview of the five looks: every main page of look A (the default), then the
home page of the other four.

Run: python -I tool/app_overview_abc.py [output.png]   (needs Pillow)
"""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

SRC = pathlib.Path("build/app_refresh_shots")
OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "build/app_overview_abc.png")

A_ROWS = [
    [("01_today", "今天"), ("02_map", "地圖"), ("03_report", "報告"),
     ("04_mine", "我的"), ("12_themes", "切換主題"), ("07_subscription", "訂閱"),
     ("08_friends", "好友")],
    [("10_check_session", "足壓健檢（進行中）"), ("05_check_result", "足壓健檢結果"),
     ("06_sign_in", "登入"), ("09_sign_up", "註冊"), ("13_devices", "我的裝置"),
     ("11_firmware", "韌體更新")],
]
OTHERS = [
    ("tech-light", "01_today", "極簡科技・白（免費）"),
    ("tech-dark", "01_today", "極簡科技・黑（免費）"),
    ("dashboard", "01_today", "B 大數字儀表板（訂閱）"),
    ("journal", "01_today", "C 紙本手帳（訂閱）"),
]
CELL_W = 300
GAP = 18
LABEL_H = 40
SECTION_H = 64
BG = (245, 242, 232)
INK = (59, 51, 37)


def font(size):
    for name in ("msjhbd.ttc", "msjh.ttc"):
        try:
            return ImageFont.truetype("C:/Windows/Fonts/" + name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def cell(path):
    img = Image.open(path).convert("RGB")
    h = round(img.height * CELL_W / img.width)
    return img.resize((CELL_W, h), Image.LANCZOS)


def main():
    sample = cell(SRC / "mascot_01_today.png")
    cell_h = sample.height
    cols = max(len(r) for r in A_ROWS)
    width = GAP + cols * (CELL_W + GAP)
    rows = len(A_ROWS) + 1
    height = (SECTION_H * 2 + rows * (LABEL_H + cell_h + GAP) + GAP)
    sheet = Image.new("RGB", (width, height), BG)
    draw = ImageDraw.Draw(sheet)
    head, label = font(30), font(22)

    y = 0
    draw.text((GAP, y + SECTION_H // 2),
              "A 粗哥手繪小鎮風　預設，所有人都有", fill=INK, font=head, anchor="lm")
    y += SECTION_H
    for row in A_ROWS:
        for col, (page, text) in enumerate(row):
            x = GAP + col * (CELL_W + GAP)
            draw.text((x + CELL_W // 2, y + LABEL_H // 2), text, fill=INK,
                      font=label, anchor="mm")
            sheet.paste(cell(SRC / f"mascot_{page}.png"), (x, y + LABEL_H))
        y += LABEL_H + cell_h + GAP
    draw.text((GAP, y + SECTION_H // 2),
              "其他四套的「今天」　B、C 要訂閱 149 才能選", fill=INK, font=head,
              anchor="lm")
    y += SECTION_H
    for col, (variant, page, text) in enumerate(OTHERS):
        x = GAP + col * (CELL_W + GAP)
        draw.text((x + CELL_W // 2, y + LABEL_H // 2), text, fill=INK,
                  font=label, anchor="mm")
        sheet.paste(cell(SRC / f"{variant}_{page}.png"), (x, y + LABEL_H))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT, optimize=True)
    print("wrote", OUT, sheet.size)


main()
