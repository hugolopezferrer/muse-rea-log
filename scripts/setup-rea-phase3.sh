#!/bin/bash
# Reproduce la Fase 3 de REA: el puente MCP como conector propio (custom.rea).
# Ejecutar DESPUES de setup-rea-phase1.sh y setup-rea-phase2.sh.
# El cliente (bin/client.py), la allowlist y la documentacion viven en
# ~/workspace/custom-connectors/custom.rea/ y persisten con el workspace.
# Este script regenera el wrapper, refresca la allowlist desde el catalogo
# vivo del servidor y comprueba el handshake.
set -euo pipefail
CONN="$HOME/workspace/custom-connectors/custom.rea"
[ -f "$CONN/bin/client.py" ] || { echo "Falta $CONN/bin/client.py (vive en el workspace)"; exit 1; }

# 1) Wrapper rea-mcp en tools/bin.
mkdir -p "$HOME/workspace/tools/bin"
cat > "$HOME/workspace/tools/bin/rea-mcp" <<'WRAPEOF'
#!/bin/bash
source "$HOME/workspace/tools/rea-env.sh"
exec python3 "$HOME/workspace/custom-connectors/custom.rea/bin/client.py" "$@"
WRAPEOF
chmod +x "$HOME/workspace/tools/bin/rea-mcp"

# 2) Allowlist desde el catalogo vivo (revisar el diff antes de darla por buena).
python3 "$CONN/bin/client.py" list-tools > /tmp/rea-tools-live.json
python3 - <<'PY'
import json
tools = json.load(open('/tmp/rea-tools-live.json'))
names = [t['name'] for t in tools]
out = {"comment": "Verified live from the REA MCP catalog via the bridge list-tools.", "tools": names}
json.dump(out, open('/home/hatch/workspace/custom-connectors/custom.rea/bin/allowed_tools.json', 'w'), indent=1)
print(f"allowlist: {len(names)} herramientas")
PY

# 3) Prueba del handshake.
"$HOME/workspace/tools/bin/rea-mcp" status
echo "Fase 3 lista. Uso: rea-mcp list-tools | describe-tool | call-tool | run-plan"
