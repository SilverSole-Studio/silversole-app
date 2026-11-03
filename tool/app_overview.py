"""Tiles the screenshots from tool/app_screenshots_test.dart into one overview
PNG: one row per variant (classic, classic-dark, mascot, mascot-dark), one
column per page.

Run: python -I tool/app_overview.py [output.png]   (needs Pillow)
"""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

SRC = pathlib.Path("build/app_refresh_shots")
OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "build/app_overview.png")
VARIANTS = [
    ("classic", "經典 淺色"),
    ("classic-dark", "經典 深色"),
    ("mascot", "插畫 淺色"),
    ("mascot-dark", "插畫 深色"),
]
PAGES = [
    ("01_today", "今天"),
    ("02_map", "地圖"),
    ("03_report", "報告"),
    ("04_mine", "我的"),
    ("05_check_result", "足壓健檢結果"),
    ("06_sign_in", "登入"),
    ("07_subscription", "訂閱"),
    ("08_friends", "好友"),
]
CELL_W = 300
GAP = 16
LABEL_H = 44
LEFT_W = 120
BG = (245, 245, 247)


def font(size):
    for name in ("msjhbd.ttc", "msjh.ttc"):
        try:
            return ImageFont.truetype("C:/Windows/Fonts/" + name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    first = Image.open(SRC / f"{VARIANTS[0][0]}_{PAGES[0][0]}.png")
    cell_h = round(first.height * CELL_W / first.width)
    width = LEFT_W + len(PAGES) * (CELL_W + GAP) + GAP
    height = LABEL_H + len(VARIANTS) * (cell_h + GAP) + GAP
    sheet = Image.new("RGB", (width, height), BG)
    draw = ImageDraw.Draw(sheet)
    head, side = font(22), font(20)
    for col, (_, label) in enumerate(PAGES):
        x = LEFT_W + GAP + col * (CELL_W + GAP)
        draw.text((x + CELL_W // 2, LABEL_H // 2), label, fill=(30, 30, 30),
                  font=head, anchor="mm")
    for row, (variant, label) in enumerate(VARIANTS):
        y = LABEL_H + GAP + row * (cell_h + GAP)
        draw.text((LEFT_W // 2, y + cell_h // 2), label, fill=(30, 30, 30),
                  font=side, anchor="mm")
        for col, (page, _) in enumerate(PAGES):
            img = Image.open(SRC / f"{variant}_{page}.png").convert("RGB")
            img = img.resize((CELL_W, cell_h), Image.LANCZOS)
            x = LEFT_W + GAP + col * (CELL_W + GAP)
            sheet.paste(img, (x, y))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT, optimize=True)
    print("wrote", OUT, sheet.size)


main()
