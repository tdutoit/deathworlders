# Session handoff (updated 2026-10-04, project shelved by the owner)

Read this first, then CLAUDE.md and docs/M5_PLAN.md.

## Where we are
- **M1-M4 complete** (M4 signed off 2026-10-04, commit bfc1657: full determinism 80/80, DoD ticked).
- **M5 (Research & Intel) in progress:** WP1-WP9 done, WP10-WP14 to go. Plan, owner decisions and
  per-WP change log: docs/M5_PLAN.md; approved tech tree: docs/M5_TECH_TREE.md.
- The M4.5 multiplayer prototype was never built; the owner decides when.
- Everything is committed and pushed to https://github.com/tdutoit/deathworlders (main).

| M5 WP | Status | Commit |
|---|---|---|
| WP1 Tech definitions (101 techs) | done | 8e47825 |
| WP2 Research simulation | done | 92938cc |
| WP3 Mk II/III hulls, gated content | done | ac3e81c |
| WP4 Listening Post, Research Station, Deep Space Array | done | 05076ac |
| WP5 Fog of war (knowledge model) | done | 8941f0a |
| WP6 Intel levels | done | 55a1ca6 |
| WP7 Refits | done | 677e43e |
| WP8 Reverse engineering | done | e7f4250 |
| WP9 Espionage | done | a4c7c33 |
| WP10 Research pact, intel sharing, tech in deals | **next** (ask the owner first: research pact "shared branches" = branches both have a tech in, or all) | |
| WP11 AI research, intel, espionage, play under fog | to do | |
| WP12 Research & Intel UI (Research Tree, Intel/Fog map mode, refit picker, espionage) | to do | |
| WP13 Player controls audit | to do | |
| WP14 Testing, balance and performance pass | to do | |

## Workflow during M5 (owner decision 2026-10-04)
- Feature WPs run only quick checks: `tools/validate_content.gd` (after data edits), `tools/lint_sim.gd` and
  `tools/smoke.gd -- 60` (small 4-AI match; prints research, stations, fog, intel, fragments, agents and
  exercises a refit and a reverse-engineering unlock). No GUT runs, harnesses or determinism runs until WP14.
- Ask the owner before inventing rules or numbers; record decisions in the M5_PLAN change log.
- Commit and push after each WP.

## Known items for WP14 (found while building WP1-WP9)
- Unit tests were not run in M5 and some will fail: signatures changed (`SpeciesTraits.species_of` ->
  `source_of`, `PlanetMods.of(state, c)`, `Economy.slots(state, c, planet, db)`), new state fields, and
  research gating.
- Research is slow: tier 1 takes ~9 months per slot vs B14's 4-6 (RP is split across slots, owner decision).
- Until WP11 every AI researches the same cheapest-first techs, so reverse engineering between AIs has
  little to copy.
- A 120-month small all-AI run had no empire-vs-empire battles, so fragments never accrue naturally.
- Placeholders to balance: Foundry II / Fabricator II jobs and upkeep, station costs, sensor strengths,
  intel rates, refit time/cost, espionage odds, Plasma Lance damage.
- Huge-galaxy 8x speed was 60.8-61.6 fps at M4 sign-off (floor 60); fog adds a daily per-empire pass, so
  re-measure.
- Nothing reads fog yet: the AI (WP11) and the UI (WP12) still see everything; convoys aren't hidden from
  raiders until the AI switches to fog.

## Tooling notes
- Godot: ~/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe. No system Python: use Blender's
  (~/Tools/blender-5.2.2-windows-x64/5.2/python/bin/python.exe) for patch and data-generator scripts.
- Run one Godot process at a time (parallel runs ran out of memory). Run `--import` after adding classes.
- In .tres files every property line must come after the `script = ` line.
- `DefDatabase.ids()/defs()` are empty before freeze: Def `validate()` code must use `all_ids()`.

## Key decisions (the "why" behind the specs)
- Deterministic lockstep multiplayer from day one: integer-only sim, seeded RNG streams,
  commands as the only way to change state.
- Resources are physical and local (except credits, research, influence): logistics is the core game.
- Automation first (sectors, governors, templates, alerts); the AI uses the same automation.
- Battles auto-resolve; player skill is intel, loadouts (fixed slots, refits) and doctrine.
- Fog of war is a per-empire knowledge model inside the sim (deterministic; AI plays fair).
- Full mod support: string IDs, layered Def database, base game ships as the "core" mod.
- Every sim feature needs player-facing UI (owner, M4): check the game as a human, not only as AI.
