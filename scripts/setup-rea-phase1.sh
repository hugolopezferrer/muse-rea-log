#!/bin/bash
# Reproduce la Fase 1 de REA en la maquina de Muse (idempotente).
# Todo vive bajo ~/workspace/tools para sobrevivir al reemplazo de la VM.
set -euo pipefail
TOOLS="$HOME/workspace/tools"
mkdir -p "$TOOLS/downloads"

# 1) JDK 21 portable (Temurin LTS) — requisito de Ghidra 12.1 y de JADX.
if [ ! -x "$TOOLS/jdk-21/bin/java" ]; then
  curl -sL -o "$TOOLS/downloads/jdk21.tar.gz" \
    "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jdk/hotspot/normal/eclipse"
  tar -xzf "$TOOLS/downloads/jdk21.tar.gz" -C "$TOOLS"
  mv "$TOOLS"/jdk-21.* "$TOOLS/jdk-21"
fi

# 2) Ghidra 12.1.4 (la serie 12.1.x que pide REA), release oficial de la NSA.
if [ ! -d "$TOOLS/ghidra_12.1.4_PUBLIC" ]; then
  curl -sL -o "$TOOLS/downloads/ghidra.zip" \
    "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip"
  unzip -q -o "$TOOLS/downloads/ghidra.zip" -d "$TOOLS"
fi

# 3) rea-agents global fijado, con prefijo npm persistente.
npm config set prefix "$TOOLS/npm-global"
npm install --global rea-agents@6.7.0 --no-audit --no-fund

# 4) Skill oficial de REA como skill propio de Muse.
if [ ! -f "$HOME/workspace/custom-skills/reverse-engineer-anything/SKILL.md" ]; then
  mkdir -p "$HOME/workspace/custom-skills"
  cp -r "$HOME/workspace/rea-test/package-inspect/extracted/skills/reverse-engineer-anything" \
        "$HOME/workspace/custom-skills/reverse-engineer-anything"
fi

# 5) Entorno y wrapper 'rea' (regenerados siempre).
cat > "$TOOLS/rea-env.sh" <<'ENVEOF'
export JAVA_HOME="$HOME/workspace/tools/jdk-21"
export GHIDRA_INSTALL_DIR="$HOME/workspace/tools/ghidra_12.1.4_PUBLIC"
export PATH="$HOME/workspace/tools/jdk-21/bin:$HOME/workspace/tools/npm-global/bin:$HOME/workspace/tools/bin:$PATH"
ENVEOF
mkdir -p "$TOOLS/bin"
printf '#!/bin/bash\nsource "$HOME/workspace/tools/rea-env.sh"\nexec "$HOME/workspace/tools/npm-global/bin/rea" "$@"\n' > "$TOOLS/bin/rea"
chmod +x "$TOOLS/bin/rea"

echo "Fase 1 lista. Verifica con:  source ~/workspace/tools/rea-env.sh && rea doctor"
