# Deathworlders — Claude Code project rules

## What this is
HFY 4X space strategy game in Godot 4.7.2 (GDScript). Specs live in /docs:
- GAME_DESIGN_SPEC.md (main), SUBSPEC_A_COMBAT.md, SUBSPEC_B_ECONOMY.md, SUBSPEC_C_DATA_MODAPI.md,
  SUBSPEC_D_SCALE.md, SUBSPEC_E_DIPLOMACY.md, SUBSPEC_F_UI.md, M1_PLAN.md, M2_PLAN.md, M3_PLAN.md and M4_PLAN.md (done).
- Read the relevant spec section before starting a task. Pinned versions: docs/ENGINE_VERSION.md.

## Hard rules (sim/)
1. No floats in sim/. Use int + FixedMath (permille). No Vector2/Vector3 in sim state.
2. No Godot randomness in sim/. Use DetRng streams only (xoshiro128**, see tools/reference/).
3. No Node, scene, Time, OS, or file access in sim/.
4. Iterate entities via IdMap (sorted). Never rely on raw Dictionary order.
5. Sim state changes ONLY in Command.apply() or tick functions.
6. Persisted/networked hashes use DetHash (FNV-1a 32), never hash().
7. Content referenced by string ID only; dense int indices never saved or sent.
8. GDScript ints are signed 64-bit: keep every intermediate product < 2^62. Use mul32() for 32-bit wraps.

## Reference implementations
- tools/reference/rng_reference.py + vectors.json: GDScript DetRng/DetHash/mul32/mix32 must reproduce
  vectors.json exactly (tests compare against it).

## Conventions
- Static typing everywhere. snake_case files/functions, PascalCase classes. One class per file.
- Views/UI read GameState and submit Commands; they never mutate state.
- All player-facing strings via loc keys (loc/en.csv). All input via InputMap actions; UI focus-navigable.

## Assets
- 3D assets come from the `blender-lowpoly-assets` skill: specs in tools/blender/specs/, output .glb in
  assets/models/. Follow docs/SUBSPEC_C_DATA_MODAPI.md §C11. Validate every .glb before committing.

## Workflow
- Tests: tools/run_tests.sh (GUT 9.7.0, headless). Must pass before a task is done.
- Determinism: tools/determinism_test.gd for any sim change (once WP11 exists).
- Content: tools/validate_content.gd after editing data/ (once WP3 exists).
- Small commits, one work-package task per commit.
- If a spec is ambiguous, ask before inventing. Record decisions in the spec's change log.
