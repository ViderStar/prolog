#!/usr/bin/env python3
"""Прогон интерактивной сессии SWI-Prolog через псевдотерминал.

Сценарий — JSON-список шагов. Шаг — строка запроса (отправляется с
переводом строки) либо объект:
    {"send": "help(halt).", "quiet": 5}  — запрос с долгим ожиданием вывода;
    {"keys": "a"}                        — одиночные нажатия клавиш;
    {"repeat": ";", "while": "[^.]\\s*$"} — жать клавишу, пока хвост вывода
                                           соответствует регулярке (перебор
                                           решений, шаги трассировки).
Результат — текстовый транскрипт ровно в том виде, в каком его видит
пользователь в терминале (без ANSI-цветов).

Запуск:
    uv run --with pexpect scripts/capture_session.py SCENARIO.json OUT.txt
"""
from __future__ import annotations

import json
import os
import re
import sys
import tempfile
import time
from pathlib import Path

import pexpect

ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]|\x1b[()][0-9A-B]|\x1b[=>]")


def clean(raw: str) -> str:
    text = ANSI.sub("", raw).replace("\r\n", "\n")
    lines = []
    for line in text.split("\n"):
        # \r внутри строки — перерисовка: остаётся последний вариант
        if "\r" in line:
            line = line.split("\r")[-1]
        # \b — стирание предыдущего символа
        while "\b" in line:
            line = re.sub(r".\x08", "", line, count=1).lstrip("\x08")
        lines.append(line.rstrip())
    return "\n".join(lines).strip("\n") + "\n"


def settle(child: pexpect.spawn, quiet: float = 0.6, limit: float = 10.0) -> str:
    """Читать вывод, пока терминал не замолчит на `quiet` секунд."""
    buf, start = [], time.time()
    while time.time() - start < limit:
        try:
            buf.append(child.read_nonblocking(65536, timeout=quiet))
        except pexpect.TIMEOUT:
            break
        except pexpect.EOF:
            break
    return "".join(buf)


def main() -> None:
    scenario_path, out_path = Path(sys.argv[1]), Path(sys.argv[2])
    scenario = json.loads(scenario_path.read_text(encoding="utf-8"))
    # Отдельные XDG_DATA_HOME/XDG_CONFIG_HOME: история запросов не тянется
    # из прошлых сессий, и нумерация приглашений начинается с 1.
    history = tempfile.mkdtemp(prefix="swipl-history-")
    env = dict(os.environ, TERM="xterm-256color", LANG="ru_RU.UTF-8",
               LC_ALL="ru_RU.UTF-8", PAGER="cat", XDG_DATA_HOME=history,
               XDG_CONFIG_HOME=history)
    child = pexpect.spawn(
        scenario.get("command", "swipl"), scenario.get("args", []),
        cwd=scenario.get("cwd", "."), env=env, encoding="utf-8",
        dimensions=(60, scenario.get("cols", 96)), timeout=10,
    )
    out = [settle(child, quiet=1.0)]
    for step in scenario["steps"]:
        if isinstance(step, str):
            step = {"send": step}
        if "send" in step:
            child.send(step["send"] + "\r")
            out.append(settle(child, quiet=step.get("quiet", 0.6)))
        elif "keys" in step:
            for key in step["keys"]:
                child.send(key)
                out.append(settle(child, quiet=0.4))
        else:
            # Жать клавишу, пока хвост вывода соответствует `while`:
            # "\? $" — трассировщик ждёт команду на порту,
            # "[^.]\s*$" — top-level предлагает следующее решение.
            pattern = re.compile(step["while"])
            for _ in range(step.get("max", 60)):
                tail = ANSI.sub("", "".join(out))[-300:]
                if not pattern.search(tail) or re.search(r"\?- $", tail):
                    break
                child.send(step["repeat"])
                out.append(settle(child, quiet=0.4))
    if child.isalive():
        child.sendeof()
        out.append(settle(child))
    child.close(force=True)
    out_path.write_text(clean("".join(out)), encoding="utf-8")
    print(f"{out_path}: {len(out_path.read_text().splitlines())} строк")


if __name__ == "__main__":
    main()
