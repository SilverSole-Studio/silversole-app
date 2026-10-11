#!/usr/bin/env python3
"""Write Google Play "what's new" files from a CHANGELOG.md section.

    play_whatsnew.py CHANGELOG.md v1.9.0 OUT_DIR [--allow-missing]

The `## v1.9.0` section carries a Chinese block under `更新內容:` and an
English block under `Updates:`. Their bullet lines become
OUT_DIR/whatsnew-zh-TW and OUT_DIR/whatsnew-en-US — the layout
r0adkll/upload-google-play's `whatsNewDirectory` reads. Anything else in the
section (the install-warning blockquote, blank lines) stays out.

Play caps each language at 500 characters, so bullets are kept whole from the
top until the next one would not fit: the most important change goes first in
CHANGELOG.md.

A missing section fails, because the GitHub Release notes need it too.
--allow-missing writes a generic note instead, for manual workflow runs.
"""

import pathlib
import re
import sys

PLAY_LIMIT = 500
FALLBACK = {
    "zh-TW": "- 錯誤修正與效能改善",
    "en-US": "- Bug fixes and improvements",
}


def section(changelog: str, tag: str) -> list[str] | None:
    lines = changelog.splitlines()
    heading = re.compile(rf"^##\s*{re.escape(tag)}\s*$")
    for i, line in enumerate(lines):
        if heading.match(line):
            body = []
            for rest in lines[i + 1 :]:
                if re.match(r"^##\s+v", rest):
                    break
                body.append(rest)
            return body
    return None


def bullets(body: list[str]) -> dict[str, list[str]]:
    blocks: dict[str, list[str]] = {"zh-TW": [], "en-US": []}
    current = None
    for line in body:
        stripped = line.strip()
        if stripped.startswith("更新內容"):
            current = "zh-TW"
        elif stripped.startswith("Updates"):
            current = "en-US"
        elif current and stripped.startswith("- "):
            blocks[current].append(stripped)
    return blocks


def fit(lines: list[str], limit: int = PLAY_LIMIT) -> str:
    kept: list[str] = []
    for line in lines:
        candidate = "\n".join(kept + [line])
        if len(candidate) > limit:
            break
        kept.append(line)
    if not kept and lines:
        # A single bullet longer than the cap: cut it rather than send nothing.
        return lines[0][: limit - 1] + "…"
    return "\n".join(kept)


def main(argv: list[str]) -> int:
    args = [a for a in argv if not a.startswith("--")]
    allow_missing = "--allow-missing" in argv
    if len(args) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    changelog_path, tag, out_dir = args

    body = section(pathlib.Path(changelog_path).read_text(encoding="utf-8"), tag)
    if body is None and not allow_missing:
        print(f"CHANGELOG.md has no '## {tag}' section", file=sys.stderr)
        return 1
    blocks = bullets(body) if body is not None else {}

    out = pathlib.Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    for lang, fallback in FALLBACK.items():
        lines = blocks.get(lang) or []
        if not lines and not allow_missing:
            print(f"'## {tag}' has no {lang} bullets", file=sys.stderr)
            return 1
        text = fit(lines) if lines else fallback
        (out / f"whatsnew-{lang}").write_text(text + "\n", encoding="utf-8")
        print(f"whatsnew-{lang}: {len(text)} chars, {text.count(chr(10)) + 1} lines")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
