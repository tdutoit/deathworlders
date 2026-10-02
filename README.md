# Deathworlders

HFY 4X space strategy game for Godot 4. Design docs in `docs/`, project rules for Claude Code in `CLAUDE.md`.

## Pre-flight checklist (M1 Plan D0): complete

- [x] D0.1 Godot 4.7.2-stable (standard build). Set `GODOT` to the console exe for `tools/run_tests.sh`.
- [x] D0.2 Git repository initialised
- [x] D0.3 Specs copied into `docs/`
- [x] D0.4 Godot MCP: `godot-mcp` Claude Code plugin (signalcompose) + editor addon in `addons/godot_mcp`
      (enabled in `project.godot`; locally patched to listen on 127.0.0.1 only). Open the project in the
      Godot editor, then check with `/mcp` or `/godot-mcp:status`.
- [x] D0.5 Blender 5.2.2 LTS + `blender-lowpoly-assets` skill (`.claude/skills/`). Set `BLENDER_PATH`.
      No system Python needed: run `validate_glb.py` with Blender's bundled `5.2/python/bin/python.exe`.
- [x] D0.6 GUT 9.7.0 in `addons/gut`, placeholder test passes headless (`tools/run_tests.sh`)
- [x] D0.7 `CLAUDE.md` written
- [x] Deterministic RNG/hash reference + test vectors (`tools/reference/`), ahead of WP2
- [x] Sample assets: human corvette & cruiser, Vess'kar corvette, railgun turret (`assets/models/`), verified in Godot 4.7.2

## M1 status

WP1–WP12 are implemented (see `docs/M1_PLAN.md` and its change log). Start the game from the editor
(F5) or the command line: main menu → New game → setup → the map.

| Keys | |
|---|---|
| WASD / middle-drag | Pan |
| Wheel / PageUp, PageDown | Zoom (galaxy → cluster) |
| Click | Select; click a selected system again (or double-click) to enter its tactical scope |
| Enter | Dive into what is under the screen centre |
| Esc / Backspace | Back out |
| Right-click | Send the selected unit to a system (otherwise back out) |
| Space, + / − | Pause, speed 1×–8× |
| Tab, F10 | Outliner, command menu (save / load / exit) |
| F2 / F3 / F4 | Fleets (and war toggle), Ship Designer, Battle Reports (M3) |
| F6 / F7 / F9 / F12 | Sectors, Logistics, Stockpiles, Alerts (M2) |

## M2 status (economy & logistics)

WP1–WP14 are implemented (see `docs/M2_PLAN.md` and the Sub-spec B change log): planet economy with dual
focus, local stockpiles, stations, freighters, routes and auto-logistics, sectors and governors,
colonisation, fuel supply, pirates, an AI autopilot, and the economy screens (planet panel, F6/F7/F9/F12,
Colonise). Click a planet, then use the panel; the top bar shows credits, research and influence.

## Running things

All commands from the project folder, with `GODOT` pointing at the console build.

| What | Command |
|---|---|
| Tests (GUT, headless) | `tools/run_tests.sh` |
| Content validation (core + `mods/`) | `$GODOT --headless -s tools/validate_content.gd [-- <mod dirs>]` |
| Sim lint (no floats etc. in `sim/`) | `$GODOT --headless -s tools/lint_sim.gd` (also part of the tests) |
| Determinism harness (~45 min) | `$GODOT --headless -s tools/determinism_test.gd -- [seeds=20] [sizes] [months=60]` |
| Galaxy stress (500 seeds × 4 sizes) | `$GODOT --headless -s tools/galaxy_stress.gd -- 500` |
| Print a galaxy | `$GODOT --headless -s tools/galaxy_debug.gd -- small "seed text" human,krothi` |
| Dev quick start / screenshot / FPS | `$GODOT --path . -- --quickstart [--size=huge] [--view=solar] [--screenshot=out.png] [--perf=5]` |
| Combat harness (A14 targets) | `$GODOT --headless -s tools/combat_harness.gd -- [runs=200] [matchup filter]` |
| Economy harness (B20 targets) | `$GODOT --headless -s tools/economy_harness.gd -- [seeds=5] [years=15] [size=small] [players=4]` |
| Screenshot an economy screen | `$GODOT --path . -- --months=24 --screen=planet\|sectors\|logistics\|stockpile\|alerts --screenshot=out.png` |
| FPS on a save at a speed | `$GODOT --path . -- --load=<save> --speed=8 --perf=20 [--no-autosave]` |

Tip: run `-s` tools under `timeout`; a script that fails to compile leaves Godot running.
