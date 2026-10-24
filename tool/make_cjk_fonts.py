"""Cuts static weights out of the system variable Noto Sans TC for
tool/friends_screenshots_test.dart (a variable font loaded into Flutter's
test engine falls back to its default weight, which for Noto Sans TC is Thin).

Run: python -I tool/make_cjk_fonts.py   (needs fontTools; output is in build/)
"""
import pathlib
import sys

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

SRC = pathlib.Path("C:/Windows/Fonts/NotoSansTC-VF.ttf")
OUT = pathlib.Path("build/friends_screenshot_fonts")
OUT.mkdir(parents=True, exist_ok=True)
for weight in (400, 500, 700):
    font = TTFont(SRC)
    inst = instancer.instantiateVariableFont(font, {"wght": weight})
    inst["OS/2"].usWeightClass = weight
    dest = OUT / f"NotoSansTC-{weight}.ttf"
    inst.save(dest)
    print("wrote", dest, dest.stat().st_size // 1024, "KB", file=sys.stderr)
