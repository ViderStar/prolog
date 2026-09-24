#!/usr/bin/env python3
"""Отрисовка транскрипта терминальной сессии в PNG «окна терминала».

Текст берётся из транскрипта, записанного capture_session.py, без правок;
подсветка (приглашение, true/false, ERROR/Warning, порты трассировки)
повторяет цвета, которые SWI-Prolog выводит в цветном терминале.

Запуск:
    uv run --with pillow scripts/render_terminal.py TRANSCRIPT.txt OUT.png \
        --title "swipl family.pl" --cmd "swipl family.pl" [--lines 1-20]
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FONT = "/System/Library/Fonts/Menlo.ttc"
SCALE = 2          # рендер в 2x для чёткости при печати
SIZE = 13          # кегль, pt
PAD = 18
BAR = 30

BG = "#FFFFFF"
FG = "#1F2328"
BAR_BG = "#ECECEC"
COLORS = {
    "prompt": "#0550AE",
    "true": "#1A7F37",
    "false": "#CF222E",
    "error": "#CF222E",
    "warning": "#9A6700",
    "comment": "#57606A",
    "shell": "#8250DF",
    "call": "#0550AE",
    "exit": "#1A7F37",
    "fail": "#CF222E",
    "redo": "#9A6700",
}


def classify(line: str) -> str | None:
    if line.startswith("artyo@MacBook-Pro "):
        return "shell"
    if re.match(r"^(\[\w+\] )?\d+ \?- ", line):
        return "prompt"
    if line.startswith("% ") and "$" not in line[:2]:
        return "comment"
    if line.startswith("ERROR"):
        return "error"
    if line.startswith("Warning"):
        return "warning"
    if re.match(r"^(true|yes)[ .;]?", line) or line.endswith("true."):
        return "true"
    if re.match(r"^false\.?$", line):
        return "false"
    m = re.match(r"^\s+(Call|Exit|Fail|Redo|Exception):", line)
    if m:
        return {"Exception": "error"}.get(m.group(1), m.group(1).lower())
    return None


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("transcript")
    ap.add_argument("out")
    ap.add_argument("--title", default="swipl")
    ap.add_argument("--cmd", default=None, help="команда оболочки в первой строке")
    ap.add_argument("--cwd", default="lab_01")
    ap.add_argument("--lines", default=None, help="диапазон строк, напр. 8-30")
    ap.add_argument("--cols", type=int, default=0)
    args = ap.parse_args()

    lines = Path(args.transcript).read_text(encoding="utf-8").splitlines()
    if args.lines:
        a, b = (int(x) for x in args.lines.split("-"))
        lines = lines[a - 1:b]
    if args.cmd:
        lines = [f"artyo@MacBook-Pro {args.cwd} % {args.cmd}"] + lines

    font = ImageFont.truetype(FONT, SIZE * SCALE, index=0)
    bold = ImageFont.truetype(FONT, SIZE * SCALE, index=1)
    cw = font.getlength("M")
    lh = int(SIZE * SCALE * 1.45)
    cols = max(args.cols, max(len(l) for l in lines), 60)
    width = int(cols * cw + 2 * PAD * SCALE)
    height = int(len(lines) * lh + 2 * PAD * SCALE + BAR * SCALE)

    img = Image.new("RGB", (width, height), BG)
    d = ImageDraw.Draw(img)
    # заголовок окна
    d.rectangle([0, 0, width, BAR * SCALE], fill=BAR_BG)
    for i, c in enumerate(["#FF5F57", "#FEBC2E", "#28C840"]):
        cx, cy, r = (16 + i * 20) * SCALE, BAR * SCALE // 2, 6 * SCALE
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=c)
    title = f"{args.cwd} — {args.title}"
    tf = ImageFont.truetype(FONT, 12 * SCALE, index=0)
    d.text(((width - tf.getlength(title)) / 2, BAR * SCALE // 2), title,
           fill="#4D4D4D", font=tf, anchor="lm")
    d.line([0, BAR * SCALE, width, BAR * SCALE], fill="#D0D0D0", width=SCALE)

    y = BAR * SCALE + PAD * SCALE
    for i, line in enumerate(lines):
        kind = "shell" if (args.cmd and i == 0) else classify(line)
        color = COLORS.get(kind, FG)
        f = bold if kind in ("prompt", "shell") else font
        if kind == "prompt":
            # приглашение — синим, сам запрос — обычным жирным
            m = re.match(r"^((\[\w+\] )?\d+ \?- )(.*)$", line)
            d.text((PAD * SCALE, y), m.group(1), fill=color, font=bold)
            d.text((PAD * SCALE + bold.getlength(m.group(1)), y), m.group(3),
                   fill=FG, font=bold)
        else:
            d.text((PAD * SCALE, y), line, fill=color, font=f)
        y += lh

    # рамка окна
    d.rectangle([0, 0, width - 1, height - 1], outline="#BFBFBF", width=SCALE)
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    img.save(args.out, dpi=(144, 144))
    print(f"{args.out}: {img.size[0]}x{img.size[1]}")


if __name__ == "__main__":
    main()
