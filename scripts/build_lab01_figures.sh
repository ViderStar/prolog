#!/usr/bin/env bash
# Пересобрать транскрипты и экранные формы для отчёта по ПР1.
# Запуск из корня репозитория: bash scripts/build_lab01_figures.sh
set -euo pipefail
cd "$(dirname "$0")/.."

T=lab_01/transcripts
F=lab_01/report/figures
mkdir -p "$T" "$F"

capture() { uv run -q --with pexpect scripts/capture_session.py "$@"; }
render()  { uv run -q --with pillow scripts/render_terminal.py "$@"; }

# 1. Установка и окружение (обычная оболочка)
(
  cd lab_01
  for c in "brew info swi-prolog | head -11" "which swipl" "swipl --version" \
           "sw_vers" "pwd" "ls -1"; do
    echo "artyo@MacBook-Pro lab_01 % $c"
    eval "$c" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | expand -t 8
  done
) > "$T/00_install.txt"

# 2. Интерактивные сессии swipl
for s in scripts/scenarios/0*.json; do
  capture "$s" "$T/$(basename "$s" .json).txt"
done

# 3. Экранные формы (строки 1–6 каждой сессии — приветствие swipl)
render "$T/00_install.txt"      "$F/fig01_install.png"      --title zsh
render "$T/01_start.txt"        "$F/fig02_start.png"        --title swipl --cmd swipl
render "$T/02_consult.txt"      "$F/fig03_consult.png"      --title "swipl family.pl" --cmd "swipl family.pl"
render "$T/03_help.txt"         "$F/fig04_help.png"         --title swipl --cmd swipl --lines 7-99
render "$T/04_trace.txt"        "$F/fig05_trace.png"        --title "swipl family.pl" --cmd "swipl family.pl" --lines 7-99
render "$T/05_basic.txt"        "$F/fig06_basic.png"        --title "swipl family.pl" --cmd "swipl family.pl" --lines 7-99
render "$T/06_variables.txt"    "$F/fig07_variables.png"    --title "swipl family.pl" --cmd "swipl family.pl" --lines 7-99
render "$T/07_backtracking.txt" "$F/fig08_backtracking.png" --title "swipl family.pl" --cmd "swipl family.pl" --lines 7-99
render "$T/08_errors.txt"       "$F/fig09_errors_a.png"     --title swipl --cmd swipl --cwd examples --lines 7-24
render "$T/08_errors.txt"       "$F/fig09_errors_b.png"     --title swipl --cwd examples --lines 25-99

# 4. Скриншоты PlDoc (встроенный веб-браузер исходников SWI-Prolog)
DOC=http://localhost:4040/pldoc/doc$PWD/lab_01
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
swipl -g "use_module(library(doc_http)), doc_server(4040), [lab_01/family]" \
      -g "thread_get_message(_)" >/dev/null 2>&1 &
SERVER=$!
trap 'kill "$SERVER" 2>/dev/null || true' EXIT
sleep 3
shot() {  # URL OUT WIDTH HEIGHT — headless Chrome не всегда завершается сам
  local profile; profile=$(mktemp -d)
  "$CHROME" --headless=new --disable-gpu --no-first-run --hide-scrollbars \
    --user-data-dir="$profile" --force-device-scale-factor=2 \
    --window-size="$3,$4" --screenshot="$2" "$1" >/dev/null 2>&1 &
  local pid=$!
  for _ in $(seq 30); do [ -s "$2" ] && break; sleep 1; done
  sleep 1; pkill -9 -f -- "$profile" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
  rm -rf "$profile" 2>/dev/null || true
}
shot "$DOC/family.pl?show=src" "$F/fig10_pldoc_src.png" 900 1100
shot "$DOC/"                   "$F/fig11_pldoc_dir.png" 900 700

uv run -q --with pillow python - "$F/fig10_pldoc_src.png" "$F/fig11_pldoc_dir.png" <<'PY'
import sys
from PIL import Image, ImageChops
for f in sys.argv[1:]:  # обрезать пустой низ страницы
    im = Image.open(f).convert("RGB")
    box = ImageChops.difference(im, Image.new("RGB", im.size, "white")).getbbox()
    im.crop((0, 0, im.width, min(im.height, box[3] + 30))).save(f)
PY
