#!/usr/bin/env bash
# Пересобрать транскрипты и экранные формы для отчёта по ПР2.
# Запуск из корня репозитория: bash scripts/build_lab02_figures.sh
set -euo pipefail
cd "$(dirname "$0")/.."

T=lab_02/transcripts
F=lab_02/report/figures
mkdir -p "$T" "$F"

capture() { uv run -q --with pexpect scripts/capture_session.py "$@"; }
render()  { uv run -q --with pillow scripts/render_terminal.py "$@"; }

# 1. Версия интерпретатора и окружение (обычная оболочка)
(
  cd lab_02
  for c in "which swipl" "swipl --version" "sw_vers" "pwd" "ls -1"; do
    echo "artyo@MacBook-Pro lab_02 % $c"
    eval "$c" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | expand -t 8
  done
) > "$T/00_install.txt"

# 2. Интерактивные сессии swipl
for s in scripts/scenarios/lab02/0*.json; do
  capture "$s" "$T/$(basename "$s" .json).txt"
done

# 3. Экранные формы (строки 1–6 каждой сессии — приветствие swipl)
C="--cwd lab_02"
render "$T/00_install.txt"          "$F/fig01_env.png"             --title zsh $C
render "$T/01_compare_task.txt"     "$F/fig02_compare_task.png"    --title "swipl compare.pl"  --cmd "swipl compare.pl"  --lines 7-99 $C
render "$T/02_compare_unique.txt"   "$F/fig03_compare_unique.png"  --title "swipl compare.pl"  --cmd "swipl compare.pl"  --lines 7-99 $C
render "$T/03_compare_errors.txt"   "$F/fig04_compare_errors.png"  --title "swipl compare.pl"  --cmd "swipl compare.pl"  --lines 7-99 $C
render "$T/04_friends_queries.txt"  "$F/fig05_friends_queries.png" --title "swipl friends.pl"  --cmd "swipl friends.pl"  --lines 7-99 $C
render "$T/05_friends_answers.txt"  "$F/fig06_friends_answers.png" --title "swipl friends.pl"  --cmd "swipl friends.pl"  --lines 7-99 $C
render "$T/06_sportsmen.txt"        "$F/fig07_sportsmen.png"       --title "swipl sportsmen.pl" --cmd "swipl sportsmen.pl" --lines 7-99 $C
