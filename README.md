# REA in Muse — Integration Log

A chronological, verifiable record of how [REA (Reverse Engineer Anything)](https://github.com/morluto/rea) was integrated into a personal [Muse](https://muse.ai) account, until it worked as an evidence-based software analyzer and cloner.

*Leer en español: [README_es.md](README_es.md)*

> **Scope and security rules of this project**
> - Only software that is owned, authorized, or permissively licensed (MIT and similar) is analyzed or cloned — always preserving the original license notice.
> - No cracking: no bypassing licenses, DRM, or protections.
> - Every installed artifact comes from its official source and was verified by SHA-256 against its publisher's digest before running.
> - No credentials live in files: this integration uses no keys or tokens.

**How to read it:** every entry follows the same template — *goal → steps → verification with evidence → error found → fix → status*. The scripts in `scripts/` reproduce each phase: this log can be re-executed, not just read.

**Final result:** REA 6.7.0 working inside Muse's virtual machine, Ghidra 12.1.4 and JADX 0.7.1 green in `rea doctor`, structured MCP access through a custom connector, and two verified clean-room clones (a todo app and a Tetris).

## The two repositories

This integration is published as a pair:

- **[hugolopezferrer/muse-rea-log](https://github.com/hugolopezferrer/muse-rea-log)** — this repo: the security log, with every chronological step, hash and verification.
- **[hugolopezferrer/muse-rea-guide](https://github.com/hugolopezferrer/muse-rea-guide)** — the step-by-step installation guide for any Muse user.

---

## Timeline

### 2026-10-18 — Day 0: discovery and integration route

- **Goal:** test REA with Muse and find the correct integration path.
- **Steps:** inspected the npm package `rea-agents` before running it (MIT license, no `preinstall`/`install`/`postinstall` scripts). Ran `rea doctor`: healthy environment, catalog of 153 CLI commands and 207 MCP tools.
- **Key finding:** the `rea setup` client list (Claude Code, Codex, Cursor, Gemini CLI, Grok Build…) **does not include Muse**. The viable route is the CLI inside Muse's virtual machine, and later a custom MCP bridge.
- **Status:** ✅ route defined.

### 2026-10-18 — Clone #1: todo app (MIT)

- **Goal:** first full analyze → rebuild → verify cycle.
- **License-driven choice:** [makingsensetraining/vanilla-javascript-todo-app](https://github.com/makingsensetraining/vanilla-javascript-todo-app), MIT (219 lines).
- **Steps:** REA analysis of the original (3 JS files parsed, 0 failures, 19 nodes, 3 endpoints). Built a clone with its own implementation (Node server without Express, `fetch` instead of `XMLHttpRequest`), original MIT license preserved.
- **Verification:** 14/14 logic checks; `/items` and `/data/items.json` responses **byte-identical** to the original running side by side; REA re-analysis of the clone clean (0 failures, 0 contradictions).
- **Status:** ✅ cycle proven.

### 2026-10-19 — Tetris and the inline-script limit

- **Goal:** level up with [jakesgordon/javascript-tetris](https://github.com/jakesgordon/javascript-tetris) (MIT).
- **Error found:** REA's JavaScript command cannot analyze the game because all of it lives in an inline `<script>` inside `index.html`.
- **Fix:** extracted the script to `game.js` (403 lines) in a research copy, without touching the original repository.
- **Verification:** REA analyzes it fully — 2/2 JS parsed, 0 failures, 0 contradictions, 2,290 semantic nodes, 60 functions.
- **Status:** ✅ unblocked (clone built on 2026-10-20, see final entry).

### 2026-10-20 — Machine audit and 3-phase plan

- **Real measurement:** 2 vCPU, ~8 GB RAM, 99 GB free, Ubuntu 24.04, Node 24.20.0. No Java (blocks both Ghidra and JADX), no native engines, REA only from the `npx` cache.
- **Plan:** Phase 1 = JDK 21 + Ghidra + pinned REA + skill. Phase 2 = JADX and per-target tools. Phase 3 = MCP bridge as a custom connector.
- **Security decision:** install everything under `~/workspace/tools` (the only place that survives a VM replacement) and capture each phase in a reproducible script.

### 2026-10-20 — Phase 1: the native engine

- **Installed:** Temurin JDK 21.0.12.1 LTS (portable), Ghidra 12.1.4 PUBLIC (official NSA release), `rea-agents` 6.7.0 global under a persistent npm prefix, REA's official skill v42 as a custom skill.
- **Integrity:** Ghidra ZIP SHA-256 = `ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db`, identical to the official digest published on GitHub.
- **Verification:** `rea doctor --provider ghidra` green on every sub-check (including "64-bit JDK 21 accepted"). Real test: an ELF binary compiled for the occasion was decompiled through REA+Ghidra and the pseudocode recovered the exact logic, including the literal string compared in the code.
- **Status:** ✅ native analysis working.

### 2026-10-20 — Phase 2: APKs and per-target tools

- **Installed:** jadx-headless-mcp 0.7.1 (the exact JAR REA requires), adb 37.0.1 (official platform-tools), tshark/capinfos 4.2.2, WABT 1.0.42, mitmproxy 12.2.3, pwntools, gdb 15.1, binwalk, unblob 26.6.4, sigrok-cli 0.7.2.
- **Integrity:** JADX JAR SHA-256 = `6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75`, identical to the hash pinned in REA's own documentation.
- **Verification per target:** a real open-source APK (F-Droid client 1.23.2, GPL) inspected with JADX — 10,765 classes, 29 permissions — and one method decompiled back to readable Java. A test pcap analyzed (correct endpoints and protocols). A WebAssembly module validated with its exports.
- **Error found:** REA does not look for WABT on the PATH: it requires the `REA_WABT_BIN_DIRECTORY` variable. Documented and fixed in the environment.
- **Status:** ✅ `rea doctor` green for Ghidra and JADX. Red only for Hopper, IDA and Kuna: paid or user-licensed, out of scope.

### 2026-10-20 — Playwright incident: diagnosis and chunked bridge

- **Symptom:** Playwright's Chromium will not download; the installer fails with `server closed connection` on every retry.
- **Sweep (read-only, nothing deleted):** local firewall ruled out, DNS correct, no `/etc/hosts` overrides. All traffic leaves through the environment's egress proxy; Playwright's CDN only redirects (307) to Google storage, and that specific route was cutting sustained transfers in that window. The same 20 MB request, repeated later from two different clients, arrived complete. **A transient network error, not a compatibility problem.**
- **Fix (the "chunked bridge"):** a third official attempt installed Chromium and ffmpeg but not the *headless shell* (116 MB). Its ZIP was downloaded straight from Google storage in **8 parallel ranges with retries** (zero cuts), integrity-verified, and placed into the cache with its marker.
- **Verification:** both browsers (145.0.7632.6) launch through playwright-core and load pages. Procedure saved in `scripts/install-playwright-bridge.sh`.
- **Status:** ✅ Playwright complete.

### 2026-10-20 — Phase 3: REA as a custom Muse connector

- **Built:** the `custom.rea` connector — a stdio MCP bridge in Python (standard library only) that starts REA's MCP server with the Phase 1+2 environment and exposes `status`, `list-tools`, `describe-tool`, `call-tool`, `run-plan`, and prompts.
- **Bridge security:** no credentials (the server is local). Calls pass an allowlist holding the **207 names verified** from the live catalog: any future server tool stays blocked until reviewed and added.
- **Verification:** handshake with protocol 2025-03-26, server `rea` 6.7.0, 207 tools. A stateful session plan (open binary with Ghidra → session → decompile → close) returned pseudocode **identical** to the Phase 1 CLI result.
- **Status:** ✅ integration on par with other harnesses, without depending on official Muse support from REA.

### 2026-10-20 — Final test: the Tetris clone

- **Goal:** confirm or rule out — on a fresh, larger target — that REA + this machine + this model really clone, after all three phases.
- **Steps:** clean-room clone built from the 2026-10-19 evidence (own implementation, different internal structure, MIT license preserved).
- **Triple verification:** automatic logic test **26/26** (movement, rotation, line clear with exact score and speed-up, game over); REA re-analysis via CLI clean (28 functions); re-analysis through the MCP bridge with the same numbers.
- **Documented deviations:** the clone evaluates the top row on line clears (the original doesn't), does not reproduce the FPS counter or the background texture (cosmetic), and on restart draws two fresh pieces instead of promoting the pre-generated next one.
- **Status:** ✅ test passed.

---

## Artifacts and integrity

| Artifact | Version | Verified SHA-256 |
|---|---|---|
| Ghidra (official NSA ZIP) | 12.1.4 | `ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db` |
| jadx-headless-mcp (JAR) | 0.7.1 | `6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75` |
| Temurin JDK (tarball) | 21.0.12.1 LTS | `ce79869e1307ed8ee1e2baa86a412b1eb5b75d10a01006d788a6f968bcfaee94` |
| rea-agents (npm, pinned) | 6.7.0 | via the official npm registry |

## What was not installed, and why

- **Hopper, IDA Pro, Kuna/JEB:** commercial. They would require the user's own license; without it, Ghidra covers the native-engine role for free.
- **Nothing with uninspected install scripts:** REA's package was reviewed before its first run.

## Surface created and how to revert

- `~/workspace/tools/` — JDK, Ghidra, global REA, WABT, platform-tools, venvs, downloads. Deleting the folder reverts the portable parts of Phases 1 and 2.
- System packages (apt): tshark, gdb, binwalk, sigrok-cli, python3-venv. Remove with `apt remove`.
- `~/.cache/ms-playwright/` — Playwright browsers. Delete the folder to remove them.
- `~/workspace/custom-skills/reverse-engineer-anything/` — REA's skill. Delete the folder to remove it.
- `~/workspace/custom-connectors/custom.rea/` — the Phase 3 MCP bridge. Delete the folder to disconnect it.
- The scripts `setup-rea-phase1.sh`, `setup-rea-phase2.sh` and `setup-rea-phase3.sh` (in `scripts/`) reinstall everything, in order, on a fresh machine.

## Honest limits

- RAM (~8 GB) rules: Ghidra and JADX work well on small and medium targets; very large binaries or APKs will be tight.
- REA does static analysis by design: it never executes the analyzed software.
- Muse is not a `rea setup` client; this integration uses REA's CLI and its standard MCP server, no private tricks.

## License

MIT — see [LICENSE](LICENSE). REA is a third-party project (morluto/rea, MIT); this log documents an integration built on top of it.
