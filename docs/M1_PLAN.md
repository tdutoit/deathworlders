# DEATHWORLDERS — M1 Build Plan: Skeleton

*Version 0.1. Turns the main spec (v1.0) and Sub-specs A–C into an ordered build plan for Godot 4.x, to be executed with Claude Code + Godot MCP.*

**Change log**
- 2026-09-30 (WP1): autoload Node shells live in `res://autoload/` (Nodes are banned from `sim/`).
- 2026-09-30 (WP2): `FixedMath.mul_permille` / `lerp_permille` floor (Sub-spec A0); added `floor_div`
  because GDScript `/` truncates toward zero. `div_round` rounds exact halves away from zero.
- 2026-09-30 (WP2): `mul32` / `rotl32` / `mix32` live in `sim/core/bits32.gd` (`Bits32`), shared by DetRng and DetHash.
- 2026-09-30 (WP2): `IdMap` uses `put` / `get_or` (Object already defines `set` / `get`); keys are all int
  or all String per map. `DetHash.hash_value` hashes a type tag plus a length prefix for strings, arrays and
  maps; an IdMap hashes the same as a Dictionary with the same entries; floats are rejected.
- 2026-10-01: sim lint (section F) added as `tools/lint_sim.gd` + a GUT test; also bans `Basis`, `Quaternion`,
  `get_tree()`, `load()`, `DirAccess`, `ResourceLoader/Saver` in `sim/`. `Vector2i`/`Vector3i` are allowed.
- 2026-10-01 (WP3): Defs and the frozen `DefDatabase` live in `sim/defs/`; file reading, JSON and mod
  discovery live in `res://io/` (`ContentLoader`, `ModManifest`, `ContentReport`, `Semver`), since `sim/` has
  no file access. The `Database` autoload owns the result. `tools/validate_content.gd` runs it headless.
- 2026-10-01 (WP3): core has 11 resources (B1 incl. Credits/Research/Influence as `physical = false`) and
  the 8 planet types from main spec 4.1 (Deathworld included). Star types, planet-type weights and
  non-human habitability are placeholders for WP7 tuning. `SpeciesDef` adds `home_planet_type`;
  `home_template` is `sol` or `standard`. `MatchPresetDef` has `kind` (`galaxy_size` / `pace`).
  `PlanetTypeDef` has no terrain or deposit table yet (no TerrainDef in M1).
- 2026-10-01 (WP4): the sim class is `MatchState` (the `GameState` autoload holds it). `Galaxy` also has
  `planets (IdMap)`; `corridors` is the sorted list of lane IDs joining clusters. Positions are `x`, `y` ints;
  owner `0` = none (IDs start at 1). Collections serialise as arrays of entity dicts in ID order.
  `checksum()` adds `meta` (tick, seed, settings, next_id) and `total` to the four planned parts.
- 2026-10-01 (WP5/6): `paused` and `speed` are sim state, changed only by `core:cmd/pause` and
  `core:cmd/set_speed`. These run with delay 0 at the next tick boundary, and the client executes due
  commands even while paused (otherwise an unpause stamped for tick + 2 could never run). Other commands
  use delay 2. Matches start paused at 1x. Pending commands live in `CommandSchedule` (owned by the
  `CommandQueue` autoload), not in `MatchState`; same-tick order is (exec_tick, player_id, seq).
- 2026-10-01 (WP5/6): `Sim.step` = `execute` (commands) + `advance` (movement, tick, day/month hooks).
  `Command.validate` sets `cmd.error` on rejection. M1 `player_id` = the issuing empire's ID. Routes are
  shortest by total lane length (ties: lower system ID). The command log is not part of the checksum.
  `Sim.replay_from(snapshot, log, until_tick)` replays from a snapshot; `replay(seed, settings, ...)`
  follows in WP7 once a match can be generated from a seed.
- 2026-10-01 (WP7): unit movement uses milli-lane-units (`progress`, `speed`; lane `length` stays in
  lane units, B7 20-40). Scouts: 500/hour, ~2.5 days per 30-unit lane.
- 2026-10-01 (WP7): positions are lane units. Systems >= 22 apart in a cluster; in-cluster lanes = minimum
  spanning tree + relative-neighbourhood graph, degree capped at 5 (tree edges kept, so always connected).
  Corridors = cluster spanning tree + 25% extra edges from each cluster's 3 nearest; they currently run
  ~55-200 lane units (tuning item). Circular galaxy mask (no spiral arms yet).
- 2026-10-01 (WP7): capital spacing comes from `MatchPresetDef.capital_min_jumps` (4/5/6/7 by size),
  placed by farthest-point selection. After 20 rerolls (`seed + attempt`) the rule relaxes by one jump
  (never needed in 500 seeds x 4 sizes, `tools/galaxy_stress.gd`). Unit tests use fewer seeds for speed.
- 2026-10-01 (WP7): new `asteroid_belt` planet type and `PlanetTypeDef.deposit_chances` (deposit richness
  1-3, placeholder until M2). `Planet.parent_id` for moons. Sol (8 planets, belt, Luna, Titan) is
  `sim/galaxy/sol_template.gd` for M1. Names come from a `name_list` Def (syllables) in
  `data/core/defs/name_list/`, not `data/core/names/`. Standard homeworlds convert the planet orbiting
  closest to radius 90 into a large planet of the species' `home_planet_type`.
- 2026-10-01 (WP8): the map views follow the Control Room style (F21/F22), not "glowing nodes". Galaxy and
  Cluster are one orthographic `MapView` with continuous zoom (operational plot below a 360-unit view
  height); Solar is a separate 3D `SolarView`; one `CameraRig` switches projection under a short fade.
  Labels are screen-space Controls. Selection goes out on `EventBus.selection_changed`. Deferred F22
  extras: APP-6 frames and echelon marks, grid-morph transition, drop lines, glass blur, edge pan,
  territory wash. `main.gd` has dev flags (`--quickstart`, `--screenshot`, `--perf`) until WP9's menu.
  Measured: Huge galaxy 144 fps (monitor cap) in all three views.
- 2026-10-01 (WP9): UI screens are built in code (`ui/`), shown by `UiRoot` under `main.tscn`'s UI layer.
  Translations from `loc/` are registered at runtime by the `Database` autoload. UI scale options
  100 / 125 / 150% (`user://settings.cfg`). The F10 menu pauses the match and restores it on resume.
  An empty seed draws a random one outside the sim. Load/Save buttons are disabled until WP10.
- 2026-10-01 (WP10): `io/save_game.gd` (`SaveGame`) writes/reads saves; `GameState.save_to/load_from`
  and the archive screen use it. Load errors are shown with English reasons inside a loc'd message
  (M1 shortcut; error codes later).
- 2026-10-01 (WP11): `tools/determinism_test.gd` (+ `tools/determinism_harness.gd`) runs each case four
  ways (fresh, repeat, save/load at the midpoint, replay from seed + log) with a scripted driver (scouts,
  weekly moves, monthly speed changes, pause blips) and diffs per-subsystem checksums monthly. Checksum
  files go to `user://determinism/` for cross-machine diffs. Full run (20 seeds x 4 sizes x 60 months)
  takes ~45 min, so the GUT suite runs one short case. Pathfinder switched to a binary heap (tie-break by
  system ID) after the harness exposed O(V^2 log V) routing.
- 2026-10-01 (WP12): core `hull` category (`HullDef` + `SlotDef`, C5 subset) with
  `core:hull/human_corvette_mk1` (A2 stats, B10 cost) using the starter's skill-built .glb. The content
  validator reads hardpoint names from the .glb's JSON chunk (`io/glb_reader.gd`). Model paths resolve
  mod-relative first, then res://. M1 stub: every scout shows this hull's model in the Solar view (LOD0,
  FACTION surface tinted with the empire colour at half saturation).
- 2026-10-01 (WP3): game version lives in `application/config/version` (0.1.0); core has a `mod.json` like any mod.

---

## Goal of M1

A running Godot project where you can:
- open a **match setup** screen, pick galaxy size / pace / seed / species slots,
- generate a **deterministic galaxy** (clusters, systems, hyperlanes, planets, a handcrafted Sol),
- zoom smoothly between **Galaxy → Cluster → Solar** views,
- run **time** (pause, 1×–8×) with hour/day/month ticks,
- send a **scout** along hyperlanes via a Command,
- **save and load**,
- and prove with a headless harness that **two runs with the same seed and commands produce identical state**.

No economy, combat, AI, or diplomacy yet. M1 is the foundation every later milestone stands on, so it favours correctness over features.

---

## D0. Pre-flight (before any code)

| # | Task | Done when |
|---|---|---|
| D0.1 | Install the latest stable **Godot 4.x** and **pin the exact version** in `docs/ENGINE_VERSION.md` | Version recorded; everyone (and CI) uses it |
| D0.2 | Create git repo `deathworlders/` | First commit with `.gitignore` for Godot (`.godot/`, `*.import` caches as appropriate) |
| D0.3 | Copy the four spec docs into `docs/` (main spec, Sub-specs A, B, C) plus this plan | Specs versioned alongside code |
| D0.4 | Set up **Claude Code** (desktop or terminal) with the **Godot MCP** server | Claude can open the project, run scenes, read the Output log |
| D0.5 | Install **Blender** (for later, not blocking M1) and create the **Blender headless skill** (via skill-creator) against the C11 asset contract | Skill generates a test cube `.glb` with a named empty |
| D0.6 | Add the **GUT** test addon (or an agreed alternative) | `godot --headless` can run an empty test suite |
| D0.7 | Write `CLAUDE.md` in the repo root (template in section E) | Claude Code reads the project rules every session |

---

## D1. Work Packages (in build order)

Size: **S** ≈ one focused session, **M** ≈ 2–3 sessions, **L** ≈ 4+ sessions.

### WP1: Project Skeleton · S
**Depends on:** D0

- Folder layout per main spec 16.9 (`sim/`, `data/`, `views/`, `ui/`, `assets/`, `tools/`, `tests/`, `mods/`).
- Autoload stubs: `GameClock`, `GameState`, `EventBus`, `Database`, `CommandQueue`.
- `Main.tscn` with an empty view container and UI layer.
- InputMap actions for everything planned in M1 (main spec 16.7): `select`, `context_action`, `zoom_in`, `zoom_out`, `pan_*`, `view_up`, `pause`, `speed_up`, `speed_down`, `open_menu`.
- `tools/run_tests.sh` runs GUT headless and returns non-zero on failure.

**Acceptance:** project opens with no errors; `run_tests.sh` passes with a placeholder test.

---

### WP2: Deterministic Foundations · M
**Depends on:** WP1

**`sim/core/fixed_math.gd`** (static functions)
- `mul_permille(a, p)`, `div_round(a, b)`, `clamp`, `isqrt`, `lerp_permille`, `dist2(x1, y1, x2, y2)`.
- All inputs and outputs `int`. Document overflow limits (keep intermediate products < 2⁶²).

**`sim/core/det_rng.gd`**: deterministic RNG
- **xoshiro128\*\*** implemented on 32-bit values stored in GDScript's 64-bit `int`, masking with `& 0xFFFFFFFF` after every operation. It only needs shifts, XOR, rotates and multiplies by 5 and 9, so products stay far below 64-bit overflow.
- Seeded via **splitmix32** from `(match_seed, stream_name_hash)`.
- API: `next_u32()`, `range(lo, hi)` (unbiased, rejection sampling), `roll_permille()`, `get_state() / set_state()`.
- Named streams: `galaxy`, `combat`, `events`, `ai`, `misc`; mods get `mod:<id>` streams.

**`sim/core/det_hash.gd`**: stable hashing
- **FNV-1a 32-bit** over UTF-8 bytes / ints (again masked to 32 bits). Don't use Godot's built-in `hash()` for anything persisted or networked, because its output isn't guaranteed across engine versions.
- `hash_state(dict)` walks keys in sorted order.

**`sim/core/id_map.gd`**: ordered containers
- Wrapper around Dictionary that iterates **sorted by key** (cache the sorted key list, rebuild on insert/remove).

**Tests:**
- RNG known-answer vectors (first 10 outputs for seed 1 match a reference computed once in Python and pasted in).
- `range()` distribution sanity (chi-square rough check over 100k rolls).
- FNV known-answer vectors.
- Fixed-math edge cases (negatives, rounding, zero).

**Acceptance:** all tests pass. The RNG reference vectors match the Python reference implementation in `tools/reference/rng_reference.py`.

---

### WP3: Def System & Database Loader · L
**Depends on:** WP2 · **Spec:** Sub-spec C1–C6, C10

- `Def` base, `ModifierDef` (C2, C4).
- M1 Def types only: `ResourceDef`, `PlanetTypeDef`, `StarTypeDef`, `SpeciesDef` (stub fields: id, name, habitability, home template, colour), `MatchPresetDef` (galaxy sizes & pace multipliers), `ModifierKeyDef`.
- **Mod discovery:** read `mods/*/mod.json` plus built-in `core` at `res://data/core/`.
- **Load order:** topological sort + tie-break rules (C6).
- **Formats:** `.tres` and `.json` (JSON → Resource via a per-category factory).
- **Ops:** `add`, `override`, `patch` (`set` / `add` / `remove` / `adjust`), `remove`.
- **Validation:** schema, references, declared modifier keys. Errors carry `mod_id + file + message`.
- **Freeze:** Database becomes read-only; build sorted per-category ID lists and dense int indices.
- **`content_hash`** via `det_hash` over `affects_sim` Defs in ID order.
- Core data for M1: 8 resources, 8 planet types (+ Deathworld), ~6 star types, 5 species stubs, 4 galaxy size presets, 3 pace presets.

**Tests:**
- Load core only: zero errors, expected counts.
- Test mods in `tests/fixtures/mods/`: an add mod, a patch mod, an override mod, a broken-reference mod (must fail with a readable error), and a dependency-order case.
- `content_hash` is stable across two loads and changes when a patch mod is added.

**Acceptance:** loading core plus the fixture mods behaves exactly as the tests describe, and a readable validation report is printed on failure.

---

### WP4: Game State Model · M
**Depends on:** WP3

Plain `RefCounted` classes in `sim/state/`, **no Node references**:

| Entity | Key fields (M1) |
|---|---|
| `GameState` | `tick`, `settings`, `match_seed`, `rng_streams`, `galaxy`, `empires`, `units`, `next_id` |
| `Galaxy` | `clusters (IdMap)`, `systems (IdMap)`, `lanes (IdMap)`, `corridors` |
| `Cluster` | `id`, `name`, `pos (int x,y)`, `system_ids` |
| `StarSystem` | `id`, `name`, `cluster_id`, `pos`, `star_type`, `planet_ids`, `lane_ids`, `owner` |
| `Hyperlane` | `id`, `a`, `b`, `length` (lane units, int) |
| `Planet` | `id`, `system_id`, `planet_type`, `size`, `orbit_index`, `orbit_radius`, `deposits`, `owner`, `orbital_slots` |
| `Empire` | `id`, `species`, `player_slot`, `capital_planet`, `color` |
| `Unit` (scout for M1) | `id`, `owner`, `kind`, `system_id`, `path`, `progress` (int), `speed` |

- Entity IDs: monotonically increasing ints from `GameState.next_id` (deterministic because creation order is deterministic).
- `to_dict()` / `from_dict()` on every entity (ints, strings and arrays only).
- `GameState.checksum()` gives per-subsystem hashes (`galaxy`, `units`, `empires`, `rng`).

**Acceptance:** round-trip `from_dict(to_dict(state))` yields an identical checksum.

---

### WP5: Clock & Tick Pipeline · S
**Depends on:** WP4

- `GameClock` (autoload, client side) accumulates frame `delta` (floats are fine here, outside the sim) and converts it to **whole hour ticks** to execute, based on speed: 1× = 1 in-game day per real second (tunable), up to 8×.
- `Sim.step()` (pure sim) executes one hour tick: apply scheduled commands for this tick → unit movement → day tick every 24 → month tick every 30 days.
- **Max ticks per frame** cap to prevent spiral-of-death at 8×.
- Pause, speed up and speed down go through Commands (so MP works later).
- Calendar: start date 2200-01-01; 30-day months, 360-day years (simple and deterministic).

**Acceptance:** at 8× the frame rate stays stable on an empty galaxy; a headless run of 12 months executes exactly 8,640 hour ticks.

---

### WP6: Commands & Local Lockstep · M
**Depends on:** WP5 · **Spec:** Sub-spec C7, main spec 18.2

- `Command` base, `CommandRegistry`, `CommandQueue` keyed by `exec_tick`.
- **Local loopback lockstep:** UI calls `CommandQueue.submit(cmd)` → scheduler stamps `exec_tick = current_tick + delay` (delay 2) → executes on that tick.
- `validate()` / `apply()` split; rejected commands are logged, not applied.
- **Command log:** every executed command is appended to `state.command_log` (type_id, player, tick, payload).
- M1 commands: `core:cmd/set_speed`, `core:cmd/pause`, `core:cmd/move_unit`, `core:cmd/debug_spawn_scout`.
- **Replay:** `Sim.replay(seed, settings, command_log)` reconstructs a match headless.

**Acceptance:** a scripted command log replayed headless produces the same checksum as the live run.

---

### WP7: Galaxy Generation · L
**Depends on:** WP4 · **Spec:** main spec 3, 4.1b, 17

All integer maths, `galaxy` RNG stream only.

1. **Clusters:** count from the size preset; placed by Poisson-disk sampling in a circular or spiral-arm mask.
2. **Systems:** 5–15 per cluster (preset weights), Poisson-disk around each cluster centre.
3. **Hyperlanes (within a cluster):** relative-neighbourhood graph (or Delaunay with the longest edges pruned); guarantee connectivity; cap degree at 5.
4. **Corridors (between clusters):** connect cluster graph by minimum spanning tree plus 20–30% extra edges for loops; each corridor becomes a long lane between the two nearest border systems.
5. **Planets:** 1–8 per system by star type; types from `PlanetTypeDef` weights by orbit zone (inner/habitable/outer); sizes and deposits from tables.
6. **Sol:** replace one system with the handcrafted Sol template (Sub-spec B19 layout; 8 planets, belt, Luna, Titan); pick the system to satisfy spacing rules.
7. **Homeworlds:** place other species' homeworlds from their home templates; enforce minimum lane distance between capitals (size-dependent); if placement fails, reroll with `seed + attempt` (deterministic).
8. **Names:** from name lists in data (`data/core/names/`).

**Tests:**
- Same seed → identical galaxy checksum (100 seeds).
- Graph fully connected for 500 seeds × 4 sizes.
- Capital spacing constraint holds.
- Sol always present with the correct planet layout.
- Generation time: Huge galaxy < 2 s headless.

**Acceptance:** all tests pass; a debug print of a Small galaxy looks sane.

---

### WP8: Views & Camera · L
**Depends on:** WP7 · **Spec:** main spec 3

Views **read** `GameState`; they never write to it.

- **CameraRig:** one 3D camera with zoom levels mapped to views; smooth transitions; mouse wheel plus InputMap actions (controller-ready).
- **GalaxyView:** clusters as low-poly glowing nodes, corridors as lines, empire colour tint, cluster labels. Click a cluster to dive in.
- **ClusterView:** systems (star-coloured markers), hyperlanes, unit markers moving along lanes (interpolated visually between ticks), system labels. Click a system to dive in.
- **SolarView:** star (emissive sphere), planets on orbit rings (placeholder low-poly spheres plus a simple planet shader by type), orbital slot markers, unit marker. Planets stay static in M1; orbital motion is cosmetic later.
- **Selection:** clicking a system, planet or unit shows its info in the Context Panel.
- **Back navigation:** `view_up` action / Esc / right-click.
- **Performance:** MultiMesh for Galaxy/Cluster markers on Huge.

**Acceptance:** Huge galaxy navigates at ≥ 60 fps on the dev PC; all three views are reachable by mouse and by keyboard actions only.

---

### WP9: UI Shell · M
**Depends on:** WP5, WP8

- **Main menu:** New Game, Load, Quit.
- **Match setup:** galaxy size, pace, seed (random or typed), player slots (species per slot, AI placeholder), crisis setting (stored, unused in M1).
- **Top bar:** date, speed indicator, pause state.
- **Context panel:** selected entity details.
- **Outliner (stub):** list of own units and systems.
- **Focus navigation:** every control has focus neighbours set; no hover-only info (main spec 16.7).
- **UI scale setting**; test at 1280×800.
- Localisation keys for all strings (`loc/en.csv`).

**Acceptance:** a full flow from main menu → setup → galaxy → back to menu works with mouse only and with keyboard only.

---

### WP10: Save / Load · S
**Depends on:** WP4, WP6 · **Spec:** Sub-spec C12

- JSON save with header (format, game version, content_hash, mods, settings, seed, tick, RNG states), `state.to_dict()`, and the command log tail.
- Deflate compression via `FileAccess.open_compressed`.
- Autosave every in-game month (rolling 3).
- A load with a mismatched `content_hash` or missing mods shows a clear error.

**Acceptance:** save at tick N, load, run to tick N+1000 → checksum equals an uninterrupted run to N+1000.

---

### WP11: Determinism Harness · M
**Depends on:** WP6, WP7, WP10

- `tools/determinism_test.gd` (headless):
  1. Generate galaxy from seed S.
  2. Apply a scripted command log (spawn scouts, move them around, speed changes).
  3. Run 5 in-game years.
  4. Record per-subsystem checksums every month.
  5. Repeat from scratch; also repeat via save/load mid-run; also via replay.
  6. Diff everything; on mismatch, report the first diverging month and subsystem.
- Run for 20 seeds × 4 sizes in CI.
- **Cross-platform check:** run on at least two machines/OSes when available and compare the checksum files.

**Acceptance:** zero mismatches across all runs.

---

### WP12 (stretch): Blender Pipeline Proof · M
**Depends on:** D0.5, WP3

- Blender skill generates `human_corvette_mk1.glb` following the C11 contract (hardpoints `HP_W_S_01`, `HP_W_S_02`, `HP_D_S_01`, `ENGINE_01`, `_LOD0/_LOD1`, `FACTION` material).
- `HullDef` stub referencing it; validator confirms hardpoints exist.
- The scout marker in SolarView uses the generated model.

**Acceptance:** the model imports cleanly, the validator passes, and it is visible in SolarView tinted with the empire colour.

---

## D2. Dependency Order

```
D0 ──► WP1 ──► WP2 ──► WP3 ──► WP4 ──┬─► WP5 ──► WP6 ──┬─► WP10 ──► WP11
                                     │                  │
                                     └─► WP7 ──► WP8 ───┴─► WP9
D0.5 + WP3 ──► WP12 (stretch, parallel)
```

Suggested sprint grouping:
1. **Foundations:** D0, WP1, WP2
2. **Data:** WP3, WP4
3. **Time & Commands:** WP5, WP6
4. **World:** WP7
5. **Seeing it:** WP8, WP9
6. **Proving it:** WP10, WP11 (+ WP12)

---

## D3. M1 Definition of Done

- [ ] All WP acceptance criteria met.
- [ ] `tools/run_tests.sh` green; determinism harness green for 20 seeds × 4 sizes.
- [ ] `tools/validate_content.gd` passes on core.
- [ ] No `float` in `sim/` (enforced by the lint in section F).
- [ ] No Node or scene references in `sim/`.
- [ ] Every player-facing string uses a loc key.
- [ ] Keyboard-only navigation works through all M1 screens.
- [ ] `docs/` updated with any spec changes discovered during the build (change log at the top of each doc).

---

## D4. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Hidden floats creep into the sim (e.g. `Vector2`, `/` on ints producing floats in some expressions) | Lint (F); use `int` type hints everywhere in `sim/`; integer division via `FixedMath` helpers |
| Dictionary iteration order bugs | `IdMap` everywhere in sim state; lint flags raw `Dictionary` fields in `sim/state/` |
| Galaxy gen too slow on Huge | Profile in WP7; spatial hashing for Poisson-disk; generate headless in a thread with a progress bar |
| Scope creep into economy/combat | M1 has no resources flowing, no battles; stubs only |
| Godot version changes mid-project | Version pinned (D0.1); upgrade only between milestones with a full determinism run |

---

## E. `CLAUDE.md` Template (repo root)

```markdown
# Deathworlders — Claude Code project rules

## What this is
HFY 4X space strategy game in Godot 4 (GDScript). Specs live in /docs:
- GAME_DESIGN_SPEC.md (main), SUBSPEC_A_COMBAT.md, SUBSPEC_B_ECONOMY.md,
  SUBSPEC_C_DATA_MODAPI.md, M1_PLAN.md. Read the relevant spec before a task.

## Hard rules (sim/)
1. No floats in sim/. Use int + FixedMath (permille). No Vector2/Vector3 in sim state.
2. No Godot randomness in sim/. Use DetRng streams only.
3. No Node, scene, Time, OS, or file access in sim/.
4. Iterate entities via IdMap (sorted). Never rely on raw Dictionary order.
5. Sim state changes ONLY in Command.apply() or tick functions.
6. Persisted/networked hashes use DetHash (FNV-1a), never hash().
7. Content referenced by string ID only; dense int indices never saved.

## Conventions
- Static typing everywhere. snake_case files/functions, PascalCase classes.
- One class per file; class_name matches file name.
- Views/UI read GameState, submit Commands; never mutate state.
- All player-facing strings via loc keys (loc/en.csv).
- All input via InputMap actions; every UI control focus-navigable.

## Workflow
- Run tests: tools/run_tests.sh (must pass before a task is done).
- Determinism: tools/determinism_test.gd for any sim change.
- Content: tools/validate_content.gd after editing data/.
- Keep commits small, one work-package task per commit.
- If a spec is ambiguous, ask before inventing. Record decisions in the spec's change log.
```

---

## F. Sim Lint (`tools/lint_sim.gd`)

A small headless script run with the tests that scans `sim/**/*.gd` and fails on:
- float literals (`\d+\.\d+`) or the `float` type,
- `Vector2`, `Vector3`, `Transform*`,
- `randi`, `randf`, `RandomNumberGenerator`,
- `Time.`, `OS.`, `FileAccess`,
- `get_node`, `$`, `Node` type hints,
- `hash(` calls.

An allow-list comment (`# lint-allow: <rule> <reason>`) handles rare justified exceptions.

---

## G. After M1

M2 (Economy & Logistics) builds directly on this plan, using Sub-spec B. It adds planets' pops and jobs, stockpiles, freighters, routes and shipyard consumption, all as Defs plus Commands plus tick systems, validated by `tests/economy_harness.gd`.
