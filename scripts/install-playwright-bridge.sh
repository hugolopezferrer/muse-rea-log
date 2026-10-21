#!/bin/bash
# Puente por lotes para instalar el Chromium de Playwright cuando el CDN
# corta la descarga de un solo flujo (visto el 2026-10-20: el instalador
# oficial fallo 3 veces con "server closed connection"; la ruta por rangos
# paralelos funciono a la primera).
# Descarga cada ZIP en 8 rangos con curl (con reintentos), verifica el ZIP
# y lo coloca en ~/.cache/ms-playwright con su INSTALLATION_COMPLETE.
set -euo pipefail
PW_DIR="$HOME/.cache/ms-playwright"
STAGE="$(mktemp -d)"
dl_chunks() { # $1=url-final $2=salida.zip
  local size; size=$(curl -sI --max-time 30 "$1" | grep -i '^content-length' | tr -d '\r' | awk '{print $2}')
  python3 -c "
size=$size; n=8; step=(size+n-1)//n
for i in range(n): print(f'{i*step}-{min(size-1,(i+1)*step-1)}')" | while IFS=- read -r a b; do
    i=$(( ${a} / ((size+7)/8) ))
    curl -sf --retry 8 --retry-all-errors --retry-delay 2 -r "$a-$b" -o "$STAGE/chunk_$i.bin" "$1" &
  done; wait
  cat "$STAGE"/chunk_*.bin > "$2"  # el glob ordena 0..7 (prefijo comun)
  unzip -t "$2" >/dev/null && echo "ZIP verificado: $2 ($(stat -c%s "$2") bytes)"
}
GS="https://storage.googleapis.com/chrome-for-testing-public/145.0.7632.6/linux64"
mkdir -p "$PW_DIR/chromium_headless_shell-1208"
dl_chunks "$GS/chrome-headless-shell-linux64.zip" "$STAGE/shell.zip"
unzip -q -o "$STAGE/shell.zip" -d "$PW_DIR/chromium_headless_shell-1208"
chmod +x "$PW_DIR/chromium_headless_shell-1208/chrome-headless-shell-linux64/chrome-headless-shell"
touch "$PW_DIR/chromium_headless_shell-1208/INSTALLATION_COMPLETE"
# El Chromium completo y ffmpeg se instalan igual si faltan:
#   dl_chunks "$GS/chrome-linux64.zip" ... -> chromium-1208/
#   ffmpeg: https://cdn.playwright.dev/builds/ffmpeg/1011/ffmpeg-linux.zip -> ffmpeg-1011/
echo "Puente aplicado. Verifica lanzando con playwright-core."
