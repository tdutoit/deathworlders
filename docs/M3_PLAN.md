# DEATHWORLDERS — M3 Build Plan: Military

*Version 0.1 (2026-10-01). Turns main spec 6.5–6.6 and 7.1–7.7 (M3 scope in section 19), Sub-spec A Part 1
(space combat), B10/B12 (ship costs, fleet supply), C5 (hulls, components, designs) and Sub-spec F5/F10/F11
into an ordered build plan. Builds on M2 (docs/M2_PLAN.md); same rules (CLAUDE.md), same tooling.*

**Change log**
- 2026-10-01: plan created. Scope decisions below agreed with the project owner.
- 2026-10-01 (WP1): combat content as data (Sub-spec A and C change logs). Open questions 2 (fighters),
  3 (assault ship, marines) and 5 (platform, pirate stats) settled with the owner. Component costs are
  placeholders inside B10's module ranges (S weapons 10 alloys / 5-8 components, M 30-40 / 10-20,
  L 60 / 25-30; defence modules 10-20 / 5-20); the Defensive Platform's upkeep is 2 credits (like other
  tier-1 military stations). Standard designs are kinetic-led for every species until the M4 species pass.
  Non-human hulls use the human model for that class (Vess'kar's corvette has its own); the classes without a
  model yet get one in WP11.

---

## Goal of M3

A match where empires build and fight with warships:
- **component-based ship designs** on fixed per-species hull layouts (C5, main spec 7.4), a design library
  with export/import codes, built at shipyards from delivered materials,
- **fleets** organised into task forces and squadrons, with **doctrine** (range, target priority, retreat
  threshold) as the player's battle control,
- **fleet supply**: fuel, ammunition from munitions, supply depots, out-of-supply penalties and attrition,
- **auto-resolved battles** per Sub-spec A (rounds, range bands, targeting and screening, point defence,
  damage pipeline, morale, retreat and pursuit, boarding and capture) with **battle reports**,
- war between empires through a **minimal war/peace toggle**, and warships against **pirates** (raiders and
  bases can now be destroyed),
- **convoy protection and raiding**: escorts, patrol zones, defensive platforms, fleets intercepting enemy
  freighters,
- AI empires keeping a **defensive fleet** through the shared autopilot,
- the M3 UI from Sub-spec F20: **Fleet panel, Ship Designer, Battle Report**,
- a headless **combat harness** checking the A14 balance targets, with the determinism and economy harnesses
  still green.

No intel levels or fog, leaders, refits, research tree, diplomacy, ground forces or species signature traits.

## Scope decisions (2026-10-01)

| Question | Decision |
|---|---|
| Who fights whom | **Pirates are always hostile.** Empires start at peace; a minimal **declare war / make peace** command (no AI diplomacy, no war goals) lets them fight. M4 replaces it with real diplomacy. |
| Warship hulls | **All species, data-driven:** each species gets the A2 combat classes with its variations as data (e.g. Vess'kar shields +40% / hull −25%, Krothi cost −35% / hull −20%). Signature traits (Stubborn, Last Stand, Persistence Hunters, Improvisers) wait for M4. |
| AI military | **Defensive autopilot:** builds a defence fleet sized to its economy, clears pirate raiders and bases in its territory, escorts and patrols its convoys, and defends its systems when at war. No AI offensives until M4. |
| Ship models | **Human set + turrets:** the human Mk I hulls and the A2 weapon turrets from the `blender-lowpoly-assets` skill (validated, with hardpoints). Other species reuse the human models, tinted, until later. |
| Boarding | **Ship boarding in M3:** Assault Ship hull, Marine Barracks module, A11 boarding of crippled ships and capture. Station capture and ground troops are M6. |
| Intel | **Full visibility:** no intel levels, no ambush rule (A3 step 3); the Designer compares against actual enemy designs. M5 adds intel and fog. |
| Commanders | **No leaders yet:** ship veterancy only. Commander traits and the flagship morale rule (A10) wait for the leaders system. |
| Convoy protection | **All four:** escort assignments, patrol zones, defensive platforms, and fleets raiding enemy convoys at war. |

## Not in M3 (deferred)

Intel levels, fog of war, ambushes, ECM deception (M5) · refits and Mk II/III hulls, tech requirements on
components (M5) · leaders, commander traits, flagship rule (M4+) · diplomacy, war goals, peace terms, AI
offensives (M4) · species signature combat traits (M4) · troop transports, ground forces, invasion, station
capture, bombardment (M6) · warp and jump drives (B12 warp/jump fuel) · terrain beyond what the galaxy already
has (nebulae and asteroid fields as battle terrain only if the generator marks them) · tech fragments
spending (salvage is counted in M3, spent in M5).

---

## D1. Work Packages (in build order)

Size: **S** ≈ one focused session, **M** ≈ 2–3 sessions, **L** ≈ 4+ sessions.

### WP1: Combat Defs & Content · L
**Spec:** A1–A2, A9, A13, B10, B12, C5
- `ComponentDef` (C5): slot type/size, weapon family, damage, shots, accuracy [L, M, C], penetration,
  tracking, ammo per shot, stat modifiers for defence/utility modules, cost.
- `HullDef` grows the combat fields it lacks: `size` (S/M/L/XL), `crew`, `shield_regen`, `pd`, `ammo_max`,
  `shipyard_size`, per-size fuel upkeep (B12) and credit upkeep (B10).
- `combat_rules` Def: every Sub-spec A number as data (hit clamp, variance, family matrix, armour K,
  ablation, PD intercept, morale terms, retreat, round cap, screening, veterancy tiers, salvage).
- Core content: the A2 weapons and defence modules plus basic utility/core modules; the A2 hull classes
  for every species (corvette, frigate, destroyer, cruiser, battlecruiser, battleship, carrier) and an
  Assault Ship, species variations as data; pirate raider hulls; a Defensive Platform station (fights,
  D9 security +10).
- Validation: slot layouts vs hardpoints on the model (C11), component slot fit, references.

### WP2: Ship Designs & Library · M
**Spec:** main spec 7.4, C5, B10
- A design = species, hull + mark, one component per slot, name, format version; stats derived from hull
  + components (summed modifiers, A0), cost = hull + components.
- Empire design list in the match state (`CmdSaveDesign`, `CmdDeleteDesign`; adding a design is a Command,
  so it stays deterministic). Default designs per species as data.
- Shipyards build designs (queue takes a design ID; shipyard size gates the hull, B10).
- Personal library across matches (`user://designs/`, UI side) and the text code
  `base64(deflate(json))`; import flags missing mod content and wrong-species hulls.

### WP3: Warships & Fleets · L
**Spec:** main spec 7.1, 7.6, A1, A10
- Warship units carry their combat state: hull, armour, shield, ammo, crew, veterancy XP, design ID.
- Fleets: owner, name, ships; task forces and squadrons formed automatically by count (7.1), manual
  reorganisation; morale per task force (A10).
- Commands: create, merge, split, rename, move (at the slowest ship's speed), set doctrine (engagement
  range, target priority, retreat threshold; formation and stance stored for later rules).
- Ship credit upkeep (B10) in the monthly settlement.

### WP4: Fleet Supply & Attrition · M
**Spec:** B12, main spec 6.5, A13
- Fuel by size, moving vs idle (B12), drawn from the nearest stockpile in supply range (extends M2's
  `Supply`); supply depots T1–T3 ranges; ammo refills from munitions (1 munition per 2 ammo).
- Out of supply: −150‰ accuracy, no ammo refill, −200 starting morale; after 30 days 1% hull attrition per
  day. Repairs at own shipyards and depots (rate to confirm, see open questions).

### WP5: Battle Engine · L
**Spec:** A3–A12
- Trigger on the hour tick when hostile formations (fleets, armed stations, defensive platforms, pirates)
  share a system; a battle persists across hour ticks, one round per hour, 48-round cap.
- Round loop exactly as A4 with simultaneous resolution; range control (A5), targeting with doctrine
  priority, top-3 pick and escort screening (A6), hit chance (A7), fleet PD pools (A8), damage pipeline with
  the family matrix, armour mitigation and ablation, crippling (A9), morale, retreat, disengage and pursuit
  (A10), boarding and capture (A11), end classification, salvage counter and veterancy (A12, A13).
- Per-battle RNG from the `combat` stream seeded `match_seed ^ battle_id` (A0); battle events recorded for
  the report; a `combat` checksum part.

### WP6: Combat Harness & Balance · M
**Spec:** A14, A26
- `tools/combat_harness.gd`: seeded battles per matchup table (mirror, hard counters, cost ratios, missiles
  vs PD, range forcing), CSV out, each run replayable from `(match_seed, battle_id, param_hash)`.
- Tune `combat_rules` data toward A14's targets and its three known issues (numbers vs counters,
  absolute defence counters, battle length); record changes in Sub-spec A's change log.

### WP7: Hostility & War Toggle · S
**Spec:** main spec 9 (minimal), A3
- Pairwise relation state (peace / war) in the match state; `CmdDeclareWar`, `CmdMakePeace` (M3 stub, no
  AI diplomacy); pirates hostile to everyone. Battles only trigger between hostile owners.

### WP8: Pirates vs Warships · S
**Spec:** B9, D9
- Raiders and bases get combat stats from pirate hull data; raiders fight fleets they meet; bases can be
  attacked and destroyed (the M2 note "bases can't be destroyed until M3").

### WP9: Convoy Protection & Raiding · M
**Spec:** main spec 6.6, B9, D9
- Escort assignment: a fleet escorts a route's or hub's freighters; a raider must beat the escort first.
- Patrol zones: a fleet patrols a set of systems, raising security (D9) and intercepting raiders.
- Defensive platforms fight in battles and add security.
- Fleets at war raid enemy convoys (B9-style passage rolls; detected freighters are lost or captured).

### WP10: Defensive Autopilot · M
**Spec:** shared automation (M2 WP11), D9
- AI slots: default designs, a defence fleet sized to the economy (credits, alloys, shipyard capacity),
  clearing raiders and bases in their territory, escorts and patrols where convoys are lost, defending own
  systems when at war. No offensives.

### WP11: Ship Assets · M
**Spec:** C11, main spec 7.4, CLAUDE.md "Assets"
- Human Mk I hulls (corvette and cruiser exist; add frigate, destroyer, battlecruiser, battleship, carrier,
  assault ship) and turrets for the A2 weapons (railgun exists; add autocannon, pulse laser, heavy laser,
  missile pod, torpedo, mass driver) with the `blender-lowpoly-assets` skill; hardpoint names match the
  hull slot layouts; every `.glb` validated before commit.

### WP12: Military UI · L
**Spec:** F5, F10, F11, F12, F20
- Fleet panel (F5): composition by task force, strength, supply and ammo, doctrine controls, orders (move,
  patrol, escort, merge, split); fleet glyphs on the map; battle markers.
- Ship Designer (F10, full screen): hull picker, slot list, component picker by family, live stats and cost,
  3D preview with turrets swapped on hardpoints, "vs enemy design" predicted matchup (headless quick battles
  against actual enemy designs: full visibility in M3), save / save as / export code / import.
- Battle Report (F11): header and result, strength-over-time chart with range phases, losses by class,
  matchup breakdown by weapon family and PD, generated key moments (loc keys), honours (MVP, veterancy),
  archive per match; alerts for battles and convoys lost to fleets.

### WP13: Military Balance & Performance Pass · M
**Spec:** A14, B20, M2 DoD
- Economy harness with AI defence fleets (upkeep, munitions, alloys) still at the accepted M2 level;
  combat harness at the A14 targets; huge galaxy with fleets and battles inside the M2 performance bars.

---

## D2. Dependency Order

| WP | Needs |
|---|---|
| WP2 | WP1 |
| WP3 | WP2 |
| WP4 | WP3 |
| WP5 | WP3 (WP4 for supply effects) |
| WP6 | WP5 |
| WP7 | WP5 |
| WP8 | WP5, WP7 |
| WP9 | WP5, WP8 |
| WP10 | WP3–WP9 |
| WP11 | WP1 (any time after; needed by WP12's designer preview) |
| WP12 | grows alongside: fleet panel with WP3, designer with WP2/WP11, battle report with WP5 |
| WP13 | everything |

## D3. M3 Definition of Done

- [ ] All WP acceptance criteria met.
- [ ] `tools/run_tests.sh` green; determinism harness green (20 seeds × 4 sizes, with combat checksums).
- [ ] Combat harness meets the A14 targets: mirror 45–55%; hard counter at equal cost 70–85%; a hard counter
      holds to ~1.25× cost; typical battles 8–20 rounds; missiles dominant at standoff without PD, weak at close.
- [ ] Economy harness with AI defence fleets at least at the M2 accepted level (66 of 80 empires).
- [ ] Huge galaxy, 8 autopilot empires with fleets, year 15: 8× speed holds ≥ 60 fps; worst hour under 50 ms
      headless.
- [ ] No Sub-spec A numbers in code (data only); content validation green; every `.glb` validated.
- [ ] Sim lint green; every player-facing string uses a loc key; all M3 screens keyboard-navigable.
- [ ] Spec change logs updated with every decision made during the build.

## D4. Open Questions (to settle at the WP, recorded in the change logs)

Sub-spec A or B has no number or rule for these; the WP proposes a placeholder and asks before relying on it.
1. **Repairs** (WP4): hull/armour repair rate at own shipyards and depots, and its cost.
2. **Fighters and bombers** (WP1): A9 has the fighter family but A2 has no hangar weapon stats.
3. **Assault Ship and Marine Barracks numbers** (WP1): A2 names the module but gives no marine/crew values.
4. **Formation and stance** (WP3): main spec 7.6 lists them; Sub-spec A has no formulas. Stored now, effects
   later unless the owner wants placeholders.
5. **Pirate ship stats** (WP8) and **defensive platform stats** (WP1): not in A2.
6. **Captured freighters** (WP9): lost (B9) or taken by the raider's owner.
7. **Battle terrain** (WP5): whether nebulae/asteroid fields exist as system properties in M3.

## D5. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Battle cost on the hour tick (many ships, 48 rounds) | Profile from WP5; resolve rounds in ID order without allocations; battles only where hostiles meet |
| Numbers overpower counters (A14 known issue) | Morale-driven retreat and screening first, then the A14 levers, all as `combat_rules` data |
| Determinism in combat (many rolls) | One RNG per battle from `combat` seeded by battle ID; simultaneous resolution; determinism harness with battles |
| AI defence fleets starving the economy | Fleet budget as a share of income; economy harness in WP13 |
| Asset volume (8 hulls, 6 turrets) | Reuse the existing pipeline and specs; human set only; other species tinted |
| UI volume (designer is a full screen with 3D) | Build each screen with its WP; designer last, after the assets |
