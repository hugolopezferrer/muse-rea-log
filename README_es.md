# REA en Muse — Bitácora de integración

*Read this in English: [README.md](README.md)*

Registro cronológico y verificable de cómo se integró [REA (Reverse Engineer Anything)](https://github.com/morluto/rea) en una cuenta personal de [Muse](https://muse.ai), hasta dejarlo operativo como analizador y clonador de software con evidencia.

> **Alcance y reglas de seguridad de este proyecto**
> - Solo se analiza o clona software propio, con autorización, o con licencia que lo permite (MIT y similares), conservando siempre el aviso de licencia original.
> - Nada de cracking: sin saltar licencias, DRM ni protecciones.
> - Todo artefacto instalado procede de su fuente oficial y se verificó por SHA-256 contra el digest de su editor antes de ejecutarse.
> - Ninguna credencial vive en archivos: esta integración no usa claves ni tokens.

**Cómo leerla:** cada entrada sigue la misma plantilla — *objetivo → pasos → verificación con evidencia → error encontrado → resolución → estado*. Los scripts de `scripts/` reproducen cada fase: la bitácora se puede re-ejecutar, no solo leer.

**Resultado final:** REA 6.7.0 operativo en la máquina virtual de Muse con Ghidra 12.1.4 y JADX 0.7.1 en verde en `rea doctor`, acceso MCP estructurado mediante un conector propio, y dos clones de sala limpia verificados (una app de tareas y un Tetris).

## Los dos repositorios

Esta integración se publica como una pareja:

- **[hugolopezferrer/muse-rea-log](https://github.com/hugolopezferrer/muse-rea-log)** — este repo: la bitácora de seguridad, con cada paso cronológico, hash y verificación.
- **[hugolopezferrer/muse-rea-guide](https://github.com/hugolopezferrer/muse-rea-guide)** — la guía de instalación paso a paso para cualquier usuario de Muse.

---

## Línea de tiempo

### 2026-10-18 — Día 0: descubrimiento y ruta de integración

- **Objetivo:** probar REA con Muse y encontrar la vía de integración correcta.
- **Pasos:** inspección del paquete npm `rea-agents` antes de ejecutarlo (licencia MIT, sin scripts `preinstall`/`install`/`postinstall`). Ejecución de `rea doctor`: entorno sano, catálogo de 153 comandos CLI y 207 herramientas MCP.
- **Hallazgo clave:** la lista de clientes de `rea setup` (Claude Code, Codex, Cursor, Gemini CLI, Grok Build…) **no incluye a Muse**. La ruta viable es la CLI dentro de la máquina virtual de Muse, y más tarde un puente MCP propio.
- **Estado:** ✅ ruta definida.

### 2026-10-18 — Clon nº 1: app de tareas (MIT)

- **Objetivo:** primer ciclo completo analizar → reconstruir → verificar.
- **Selección por licencia:** [makingsensetraining/vanilla-javascript-todo-app](https://github.com/makingsensetraining/vanilla-javascript-todo-app), MIT (219 líneas).
- **Pasos:** análisis REA del original (3 JS parseados, 0 fallos, 19 nodos, 3 endpoints). Construcción de un clon con implementación propia (servidor Node sin Express, `fetch` en vez de `XMLHttpRequest`), licencia MIT original preservada.
- **Verificación:** 14/14 checks de lógica; respuestas de `/items` y `/data/items.json` **byte a byte idénticas** al original en ejecución lado a lado; reanálisis REA del clon limpio (0 fallos, 0 contradicciones).
- **Estado:** ✅ ciclo demostrado.

### 2026-10-19 — El Tetris y el límite del script en línea

- **Objetivo:** subir el nivel con [jakesgordon/javascript-tetris](https://github.com/jakesgordon/javascript-tetris) (MIT).
- **Error encontrado:** el comando JavaScript de REA no analiza el código porque todo el juego vive en un `<script>` en línea dentro de `index.html`.
- **Resolución:** extracción del script a `game.js` (403 líneas) en una copia de investigación, sin tocar el repositorio original.
- **Verificación:** REA lo analiza completo — 2/2 JS parseados, 0 fallos, 0 contradicciones, 2.290 nodos semánticos, 60 funciones.
- **Estado:** ✅ desbloqueado (clon construido el 2026-10-20, ver entrada final).

### 2026-10-20 — Auditoría de la máquina y plan en 3 fases

- **Medición real:** 2 vCPU, ~8 GB RAM, 99 GB libres, Ubuntu 24.04, Node 24.20.0. Sin Java (bloquea Ghidra y JADX), sin motores nativos, REA solo vía caché de `npx`.
- **Plan:** Fase 1 = JDK 21 + Ghidra + REA fijado + skill. Fase 2 = JADX y herramientas por tipo de objetivo. Fase 3 = puente MCP como conector propio.
- **Decisión de seguridad:** instalar todo bajo `~/workspace/tools` (lo único que sobrevive al reemplazo de la máquina virtual) y dejar cada fase en un script reproducible.

### 2026-10-20 — Fase 1: el motor nativo

- **Instalado:** Temurin JDK 21.0.12.1 LTS (portable), Ghidra 12.1.4 PUBLIC (release oficial de la NSA), `rea-agents` 6.7.0 global con prefijo npm persistente, skill oficial de REA v42 como skill propio.
- **Integridad:** SHA-256 del ZIP de Ghidra = `ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db`, idéntico al digest oficial publicado en GitHub.
- **Verificación:** `rea doctor --provider ghidra` en verde en todos sus chequeos (incluido «JDK 21 de 64 bits aceptado»). Prueba real: un binario ELF compilado para la ocasión fue descompilado por REA+Ghidra y el pseudocódigo recuperó la lógica exacta, incluida la cadena literal comparada en el código.
- **Estado:** ✅ análisis nativo operativo.

### 2026-10-20 — Fase 2: APK y herramientas por objetivo

- **Instalado:** jadx-headless-mcp 0.7.1 (el JAR exacto que pide REA), adb 37.0.1 (platform-tools oficiales), tshark/capinfos 4.2.2, WABT 1.0.42, mitmproxy 12.2.3, pwntools, gdb 15.1, binwalk, unblob 26.6.4, sigrok-cli 0.7.2.
- **Integridad:** SHA-256 del JAR de JADX = `6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75`, idéntico al que REA fija en su propia documentación.
- **Verificación por objetivo:** APK real de código abierto (cliente de F-Droid 1.23.2, GPL) inspeccionado con JADX — 10.765 clases, 29 permisos — y un método descompilado de vuelta a Java legible. Captura pcap de prueba analizada (endpoints y protocolos correctos). Módulo WebAssembly validado con sus exportaciones.
- **Error encontrado:** REA no busca WABT en el PATH: exige la variable `REA_WABT_BIN_DIRECTORY`. Documentado y corregido en el entorno.
- **Estado:** ✅ `rea doctor` con Ghidra y JADX en verde. En rojo solo Hopper, IDA y Kuna: de pago o con licencia del usuario, fuera del alcance.

### 2026-10-20 — Incidente Playwright: diagnóstico y puente por lotes

- **Síntoma:** el Chromium de Playwright no se descarga; el instalador falla con `server closed connection` en todos los reintentos.
- **Barrido (solo lectura, sin borrar nada):** cortafuegos local descartado, DNS correcto, sin entradas en `/etc/hosts`. Todo el tráfico sale por el proxy de salida del entorno; el CDN de Playwright solo redirige (307) al almacenamiento de Google, y esa ruta concreta cortaba las transferencias sostenidas en esa ventana. La misma petición de 20 MB, repetida después con dos clientes distintos, llegó completa. **Error de comunicación transitorio, no de compatibilidad.**
- **Resolución («puente por lotes»):** una tercera intentona oficial dejó instalados Chromium y ffmpeg pero no el *headless shell* (116 MB). Su ZIP se descargó directo del almacenamiento de Google en **8 rangos en paralelo con reintentos** (cero cortes), se verificó su integridad y se colocó en la caché con su marcador.
- **Verificación:** ambos navegadores (145.0.7632.6) arrancan vía playwright-core y cargan páginas. Procedimiento guardado en `scripts/install-playwright-bridge.sh`.
- **Estado:** ✅ Playwright completo.

### 2026-10-20 — Fase 3: REA como conector propio de Muse

- **Construido:** conector `custom.rea` — un puente MCP por stdio en Python (solo librería estándar) que arranca el servidor MCP de REA con el entorno de las fases 1 y 2, y expone `status`, `list-tools`, `describe-tool`, `call-tool`, `run-plan` y prompts.
- **Seguridad del puente:** ninguna credencial (el servidor es local). Las llamadas pasan por una lista permitida con los **207 nombres verificados** del catálogo vivo: una herramienta futura del servidor queda bloqueada hasta ser revisada y añadida.
- **Verificación:** handshake con protocolo 2025-03-26, servidor `rea` 6.7.0, 207 herramientas. Plan de sesión con estado (abrir binario con Ghidra → sesión → descompilar → cerrar) con pseudocódigo **idéntico** al obtenido por CLI en la Fase 1.
- **Estado:** ✅ integración equivalente a la de otros harness, sin depender de que REA soporte Muse oficialmente.

### 2026-10-20 — Prueba final: clon del Tetris

- **Objetivo:** descartar o confirmar, con un objetivo fresco y mayor, que REA + esta máquina + este modelo clonan de verdad tras las tres fases.
- **Pasos:** clon de sala limpia desde la evidencia del 2026-10-19 (implementación propia, otra estructura interna, licencia MIT preservada).
- **Verificación triple:** prueba lógica automática **26/26** (movimiento, rotación, limpieza de línea con puntuación y aceleración exactas, fin de partida); reanálisis REA por CLI limpio (28 funciones); reanálisis por el puente MCP con los mismos números.
- **Desviaciones documentadas:** el clon evalúa la fila superior al limpiar líneas (el original no), no reproduce el contador de FPS ni la textura de fondo (cosmética), y al reiniciar sortea dos piezas frescas en vez de promover la siguiente.
- **Estado:** ✅ prueba superada.

---

## Artefactos e integridad

| Artefacto | Versión | SHA-256 verificado |
|---|---|---|
| Ghidra (ZIP oficial NSA) | 12.1.4 | `ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db` |
| jadx-headless-mcp (JAR) | 0.7.1 | `6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75` |
| Temurin JDK (tarball) | 21.0.12.1 LTS | `ce79869e1307ed8ee1e2baa86a412b1eb5b75d10a01006d788a6f968bcfaee94` |
| rea-agents (npm, fijado) | 6.7.0 | vía registro npm oficial |

## Qué no se instaló, y por qué

- **Hopper, IDA Pro, Kuna/JEB:** comerciales. Requerirían la licencia del usuario; sin ella, Ghidra cubre el rol de motor nativo sin coste.
- **Nada con scripts de instalación no inspeccionados:** el paquete de REA se revisó antes de la primera ejecución.

## Superficie creada y reversión

- `~/workspace/tools/` — JDK, Ghidra, REA global, WABT, platform-tools, venvs y descargas. Borrar la carpeta revierte las fases 1 y 2 portables.
- Paquetes de sistema (apt): tshark, gdb, binwalk, sigrok-cli, python3-venv. Se retiran con `apt remove`.
- `~/.cache/ms-playwright/` — navegadores de Playwright. Borrar la carpeta los elimina.
- `~/workspace/custom-skills/reverse-engineer-anything/` — el skill de REA. Borrar la carpeta lo elimina.
- `~/workspace/custom-connectors/custom.rea/` — el puente MCP de la Fase 3. Borrar la carpeta lo desconecta.
- Los scripts `setup-rea-phase1.sh`, `setup-rea-phase2.sh` y `setup-rea-phase3.sh` (en `scripts/`) reinstalan todo en orden sobre una máquina nueva.

## Límites honestos

- La RAM (~8 GB) manda: Ghidra y JADX trabajan bien en objetivos pequeños y medianos; binarios o APK muy grandes irán justos.
- REA hace análisis estático por diseño: nunca ejecuta el software analizado.
- Muse no es un cliente soportado por `rea setup`; esta integración usa su CLI y su servidor MCP estándar, no ningún truco privado.

## Licencia

MIT — ver [LICENSE](LICENSE). REA es un proyecto de terceros (morluto/rea, MIT); esta bitácora documenta una integración hecha sobre él.
