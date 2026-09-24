#!/usr/bin/env python3
"""Банк вопросов Moodle (GIFT) → LaTeX-список для визуальной проверки в отчёте.

Запуск:
    python3 scripts/gift_to_tex.py lab_01/moodle_questions_gift.txt \
        lab_01/report/questions_pretty.tex
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

QUESTION = re.compile(r"::(?P<title>.+?)::\s*(?P<text>.+?)\s*\{(?P<body>.*?)\n\}", re.S)
ANSWER = re.compile(r"^\s*([=~])(.*)$", re.M)
TEX_SPECIAL = {"\\": r"\textbackslash{}", "&": r"\&", "%": r"\%", "$": r"\$",
               "#": r"\#", "_": r"\_", "{": r"\{", "}": r"\}",
               "~": r"\textasciitilde{}", "^": r"\textasciicircum{}"}


def gift_unescape(s: str) -> str:
    return re.sub(r"\\([~=#{}:])", r"\1", s).strip()


def tex(s: str) -> str:
    out = "".join(TEX_SPECIAL.get(c, c) for c in s)
    # код Пролога в вопросах — моноширинным: ?- ..., предикаты вида name(...)
    return out.replace("?-", r"\texttt{?-}")


def main() -> None:
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    text = src.read_text(encoding="utf-8")
    items = []
    for m in QUESTION.finditer(text):
        answers = [(k, gift_unescape(v)) for k, v in ANSWER.findall(m.group("body"))]
        right = next(v for k, v in answers if k == "=")
        opts = "\n".join(rf"\item {tex(v)}" for _, v in answers)
        items.append(
            rf"\item {tex(gift_unescape(m.group('text')))}" "\n"
            r"\begin{itemize}[label=$\square$, leftmargin=1.5cm, itemsep=0.2em, topsep=0.3em]" "\n"
            f"{opts}\n"
            r"\end{itemize}" "\n"
            rf"{{\small\textit{{Правильный ответ: {tex(right)}{'' if right.endswith('.') else '.'}}}}}" "\n"
        )
    dst.write_text(
        "\\small\n"
        "\\begin{enumerate}[label=\\textbf{\\arabic*.}, leftmargin=0pt, itemsep=1.2em]\n"
        + "\n".join(items)
        + "\\end{enumerate}\n\\normalsize\n",
        encoding="utf-8",
    )
    print(f"{dst}: {len(items)} вопросов")


if __name__ == "__main__":
    main()
