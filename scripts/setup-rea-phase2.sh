#!/bin/bash
# Reproduce la Fase 2 de REA en la maquina de Muse (idempotente).
# Ejecutar DESPUES de setup-rea-phase1.sh. Las piezas portables viven bajo
# ~/workspace/tools; las de apt (tshark/gdb/binwalk) se reinstalan con este
# script si la VM se reemplaza.
set -euo pipefail
TOOLS="$HOME/workspace/tools"
mkdir -p "$TOOLS/downloads" "$TOOLS/android" "$TOOLS/venvs" "$TOOLS/bin"

# 1) JADX headless MCP 0.7.1 (el JAR exacto que pide REA; SHA-256 fijado por REA).
JAR="$TOOLS/android/jadx-headless-mcp-0.7.1-all.jar"
if [ ! -f "$JAR" ]; then
  curl -sfL -o "$JAR" "https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.7.1/jadx-headless-mcp-0.7.1-all.jar"
fi
echo '6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75  '"$JAR" | sha256sum -c -

# 2) adb: platform-tools oficiales de Google (portable).
if [ ! -x "$TOOLS/platform-tools/adb" ]; then
  curl -sfL -o "$TOOLS/downloads/platform-tools.zip" "https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
  unzip -q -o "$TOOLS/downloads/platform-tools.zip" -d "$TOOLS"
fi

# 3) Paquetes de sistema que REA usa como proveedores (pcap, crashes, firmware).
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq tshark gdb binwalk python3-venv sigrok-cli

# 4) WABT 1.0.42 (wasm2wat / wat2wasm / wasm-objdump), portable.
if [ ! -x "$TOOLS/wabt/bin/wasm2wat" ]; then
  curl -sfL -o "$TOOLS/downloads/wabt.tar.gz" "https://github.com/WebAssembly/wabt/releases/download/1.0.42/wabt-1.0.42-linux-x64.tar.gz"
  mkdir -p "$TOOLS/wabt"
  tar --no-same-owner -xzf "$TOOLS/downloads/wabt.tar.gz" -C "$TOOLS/wabt" --strip-components=1
fi

# 5) mitmproxy en su propio venv (mitmdump para capturas de red de REA).
if [ ! -x "$TOOLS/venvs/mitm/bin/mitmdump" ]; then
  python3 -m venv "$TOOLS/venvs/mitm"
  "$TOOLS/venvs/mitm/bin/pip" install -q --upgrade pip
  "$TOOLS/venvs/mitm/bin/pip" install -q mitmproxy
fi

# 6) pwntools + unblob en un venv de utilidades.
if [ ! -x "$TOOLS/venvs/repy/bin/pwn" ]; then
  python3 -m venv "$TOOLS/venvs/repy"
  "$TOOLS/venvs/repy/bin/pip" install -q --upgrade pip
  "$TOOLS/venvs/repy/bin/pip" install -q pwntools unblob
fi
ln -sf "$TOOLS/venvs/mitm/bin/mitmdump"  "$TOOLS/bin/mitmdump"
ln -sf "$TOOLS/venvs/mitm/bin/mitmproxy" "$TOOLS/bin/mitmproxy"
ln -sf "$TOOLS/venvs/repy/bin/unblob"    "$TOOLS/bin/unblob"
ln -sf "$TOOLS/venvs/repy/bin/pwn"       "$TOOLS/bin/pwn"

# 7) Chromium para los comandos web de REA (via el playwright-core que trae rea-agents).
PW="$TOOLS/npm-global/lib/node_modules/rea-agents/node_modules/playwright-core"
node "$PW/cli.js" install chromium

# 8) Entorno (regenerado): incluye REA_JADX_MCP_JAR y las rutas nuevas.
cat > "$TOOLS/rea-env.sh" <<'ENVEOF'
export JAVA_HOME="$HOME/workspace/tools/jdk-21"
export GHIDRA_INSTALL_DIR="$HOME/workspace/tools/ghidra_12.1.4_PUBLIC"
export REA_JADX_MCP_JAR="$HOME/workspace/tools/android/jadx-headless-mcp-0.7.1-all.jar"
export REA_WABT_BIN_DIRECTORY="$HOME/workspace/tools/wabt/bin"
export PATH="$HOME/workspace/tools/jdk-21/bin:$HOME/workspace/tools/npm-global/bin:$HOME/workspace/tools/bin:$HOME/workspace/tools/platform-tools:$HOME/workspace/tools/wabt/bin:$PATH"
ENVEOF

echo "Fase 2 lista. Verifica con:  source ~/workspace/tools/rea-env.sh && rea doctor"
