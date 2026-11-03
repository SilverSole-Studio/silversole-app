"""Cuts the three theme fonts down to what the app draws and writes them to
assets/fonts/. All three are SIL OFL 1.1 (licence texts sit next to them).

  * Chiron GoRound TC  -> look A (粗哥手繪小鎮)   static 500 / 700 / 900
  * LXGW WenKai TC     -> look C (紙本手帳)       Regular / Bold
  * Big Shoulders Display -> look B numerals      static 900 (Latin only)

Sources (the google/fonts repository, ofl/ folder):
  chirongoroundtc/ChironGoRoundTC[wght].ttf
  lxgwwenkaitc/LXGWWenKaiTC-Regular.ttf, LXGWWenKaiTC-Bold.ttf
  bigshouldersdisplay/BigShouldersDisplay[wght].ttf

The glyph set is every character in strings.csv and in the Dart sources, plus
ASCII, full-width forms and the CJK punctuation block. A character outside the
set (say, a name a user typed) is drawn by the system font, glyph by glyph.

Run: python -I tool/make_theme_fonts.py <folder with the downloaded fonts>
(needs fontTools; run it again whenever the translations gain new characters)
"""
import pathlib
import re
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

SRC = pathlib.Path(sys.argv[1])
ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "fonts"


def wanted_chars() -> set[str]:
    text = (ROOT / "assets/translations/strings.csv").read_text(encoding="utf-8")
    for f in (ROOT / "lib").rglob("*.dart"):
        text += f.read_text(encoding="utf-8")
    chars = {c for c in text if ord(c) >= 0x2000}
    chars |= {chr(c) for c in range(0x20, 0x7F)}
    chars |= {chr(c) for c in range(0x3000, 0x3040)}  # CJK punctuation
    chars |= {chr(c) for c in range(0xFF00, 0xFFF0)}  # full-width forms
    chars |= set("·・—…「」『』（）、，。：；！？％～")
    return chars


def cut(font: TTFont, chars: set[str], dest: pathlib.Path) -> None:
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = [1, 2, 3, 4, 6]
    opts.notdef_outline = True
    opts.hinting = False
    sub = subset.Subsetter(opts)
    sub.populate(text="".join(chars))
    sub.subset(font)
    font.save(dest)
    print("wrote", dest.name, dest.stat().st_size // 1024, "KB", file=sys.stderr)


def main() -> None:
    chars = wanted_chars()
    print(len(chars), "characters", file=sys.stderr)
    OUT.mkdir(parents=True, exist_ok=True)

    vf = SRC / "ChironGoRoundTC[wght].ttf"
    for wght, name in ((500, "Medium"), (700, "Bold"), (900, "Black")):
        font = instancer.instantiateVariableFont(TTFont(vf), {"wght": wght})
        font["OS/2"].usWeightClass = wght
        cut(font, chars, OUT / f"ChironGoRoundTC-{name}.ttf")

    for name in ("Regular", "Bold"):
        cut(TTFont(SRC / f"LXGWWenKaiTC-{name}.ttf"), chars,
            OUT / f"LXGWWenKaiTC-{name}.ttf")

    latin = {chr(c) for c in range(0x20, 0x7F)}
    font = instancer.instantiateVariableFont(
        TTFont(SRC / "BigShouldersDisplay[wght].ttf"), {"wght": 900})
    font["OS/2"].usWeightClass = 900
    cut(font, latin, OUT / "BigShouldersDisplay-Black.ttf")


if __name__ == "__main__":
    main()
