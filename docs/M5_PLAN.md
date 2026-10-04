# DEATHWORLDERS — M5 Build Plan: Research & Intel

*Version 0.1 (2026-10-04). Turns main spec 7.4 (Mk hulls, refits), 7.5 (intel levels), 8 (research),
12 (espionage), B14 (research numbers), D12 (fog of war), A3 (ambush rule), E4/E6/E13 (research pact, intel
sharing, tech in deals, Admiral and Deathworld difficulty) and F10/F13 (designer vs known enemy, Research
Tree) into an ordered build plan. Builds on M4 (docs/M4_PLAN.md); same rules (CLAUDE.md), same tooling,
with the workflow change below.*

**Change log**
- 2026-10-04: plan created. Scope decisions below agreed with the project owner, including the workflow
  change: testing and balance move to the end of the milestone (WP14).

## Goal of M5

A match where knowledge is a resource:
- a **fixed research tree** of about 100 techs in six branches and five tiers, with species nodes and
  exclusive specialisations, researched in parallel slots from global research points (B14),
- **tech-gated content**: Mk II and Mk III hulls for every species, advanced components, buildings and
  stations that research unlocks, plus a starting tech set per species so everything M4 used stays available,
- **fog of war** as sim state: a per-empire knowledge model (Unknown / Explored / Covered), sensor coverage,
  the detection contest, ghosts and stale ownership (D12), with the Off / Standard / Hardcore setting,
- **intel levels 0-4** per empire on each other empire, from listening posts, scouts, battles, captured
  ships, allied sharing and spies, feeding the ambush rule (A3), power estimates and battle-report estimates,
- **refits** at shipyards and depots, and a designer that predicts against the *known* enemy profile,
- **reverse engineering**: tech fragments per faction unlocking that faction's techs at half cost,
- **espionage** (light layer): agents, four missions and counter-intelligence,
- the **research pact** and **intel sharing** treaties, and tech in deals,
- **AI** that researches by personality, refits by intel, uses spies and plays under fog,
- the **Research Tree** screen, the **Intel / Fog** map mode, the refit picker and the espionage UI,
- a final test, balance and performance pass (WP14) bringing every harness back to its accepted level.

No ground war (M6), events, crises, Legend-driven content or derelicts (M7), campaign (M8), mod-script API
(M9), leaders, federations or the M4.5 multiplayer prototype (still unbuilt; the owner decides when).

## Scope decisions (2026-10-04)

| Question | Decision |
|---|---|
| Testing workflow | **End of milestone.** WP1-WP13 ship code with only a compile check and sim lint (seconds). Unit tests, the determinism run, all harnesses, balance and performance move into WP14. Existing tests may break during WP1-WP13; WP14 fixes or rewrites them. |
| Tree size | **About 100 techs:** 6 branches (Physics, Engineering, Logistics, Society, Military Doctrine, Xeno Studies) x 5 tiers x about 3 techs, plus species nodes and exclusive pairs. B14 costs and "3 techs of the tier below in the same branch". |
| Mk hulls | **Mk II and Mk III for every species,** reusing the Mk I models until a later art pass. |
| Extras | **All four:** research pact + intel sharing treaties, reverse engineering, Listening Post + Research Station, espionage agents. |

## Workflow during M5 (owner decision 2026-10-04)

Per WP: write the code, run a headless compile check (`godot --headless --path . --quit` after import, plus
`tools/lint_sim.gd`, and `tools/validate_content.gd` when data/ changed), commit, push, start the next WP.
No GUT runs, determinism runs or harnesses until WP14. Unit tests for new code are written in WP14, where
they also find the bugs. The hard rules (no floats, DetRng, IdMap order, Commands only) still apply to every
line, since WP14 cannot cheaply untangle a determinism bug from 13 WPs ago.

## Carried over from M4

- Admiral's +1 intel level and Deathworld's full-vision cheat wait for intel and fog (E13): WP6.
- Defence pact and alliance opinion gates were lowered by 10 until research and intel pacts exist
  (owner, M4 WP14): WP10 restores them to the E4 values.
- `Empire.tech_fragments` is one number; reverse engineering needs it per faction: WP8.
- 8x speed on a huge galaxy is at 60.8-61.6 fps against a 60 floor: fog's daily coverage pass (WP5) must
  be incremental from the start, and WP14 re-measures.

---

## D1. Work Packages

### WP1: Tech Definitions & Tree Content · L
**Spec:** main spec 8.1-8.2, B14, C (`tech` row, tree validation)
- `TechDef` (`branch`, `tier`, `cost`, `prereqs[]`, `exclusive_with[]`, `unlocks[]`, `modifiers[]`,
  `species_only[]`), `requires_tech[]` on hulls, components, buildings and stations.
- About 100 core techs. The tech list (names, effects, unlocks) is proposed at the WP and approved before
  writing the data. Exclusive pair Kinetic Supremacy vs Energy Mastery; species nodes per species.
- `SpeciesDef.starting_techs`: every species starts with what M4 content needs.
- Validation: no cycles, tier rule (3 of the tier below, same branch), exclusive pairs symmetric, unlocks
  resolve, species_only species exist.

### WP2: Research Simulation · M
**Spec:** B14, B3 (month tick), C (`set_research` command, `on_tech_researched`)
- Research points from the global stock feed parallel slots (2, +1 at Tier 3 Society); queue per empire;
  pace scales costs; completion on the month tick; overflow carries over.
- `Empire.techs` (researched), slot progress and queue in saves and the checksum (`research` part).
- Researched techs apply modifiers (cache dirty flag) and unlock content: BuildRules, Shipyards and the
  designer check `requires_tech`. Exclusive techs lock their partner.
- Commands `set_research`, `queue_research`, `dequeue_research`.

### WP3: Mk II / Mk III Hulls & Gated Content · L
**Spec:** main spec 7.4, A2 (slot layouts), B13 (advanced buildings), C11 (models)
- Mk II and Mk III hull Defs for the 8 warship classes x 5 species (80 Defs): extra or larger slots, more hull
  and cost, same model as Mk I. Slot layouts proposed at the WP.
- Advanced components (Mk II/III weapons and defences, sensors, stealth, salvage bay) and advanced buildings
  (150 alloys + 30 components, 150 days, B13).
- Standard designs per tier so the AI has something to build.

### WP4: Listening Post, Research Station, Deep Space Array · S
**Spec:** main spec 5 (stations), B13, B14, D12
- Listening Post T1-T3 (coverage 2/3/4 lanes, sensor strength), Research Station (+15 RP), Deep Space Array
  (Core building, +3 lanes). Earth's starting Listening Post at Neptune (B19) finally exists.
- Construction screen offers them; governor and autopilot build them by rule.

### WP5: Fog of War (knowledge model) · L
**Spec:** D12, main spec 17 (fog setting)
- Per-empire knowledge per system: Unknown / Explored / Covered, last-seen ownership and date.
- Coverage on day ticks, incremental when sources move or change; the detection contest (signature vs
  sensor strength minus stealth); convoys invisible outside coverage.
- Ghosts: contacts that leave coverage keep last-known size and timestamp, fading over 90 days.
- Match setting Off / Standard / Hardcore (no ghosts, estimates only); Off behaves as M4.

### WP6: Intel Levels · M
**Spec:** main spec 7.5, A3 step 3, D12, E13
- Intel level 0-4 per directed empire pair (and per formation where it matters): gains from coverage, scouts,
  battles against the faction (partial profile carried forward), captured ships, intel sharing, agents;
  decay without sources. Rates proposed at the WP.
- The A3 ambush rule (intel >= 3 vs <= 1: free opening round).
- Estimates with error bars for power and battle losses at low intel.
- Admiral +1 intel level; Deathworld full vision (labelled cheat).

### WP7: Refits · M
**Spec:** main spec 7.4 ("refit before battle"), F4 fleet panel, F10 ("Set as refit")
- `refit_fleet`: ships docked at an own shipyard or depot swap to another design of the same hull; time
  and cost from the component difference (numbers proposed at the WP).
- Mk upgrades (Mk I to Mk II) as a refit at a shipyard of the right size, or rebuild only (proposed at the WP).

### WP8: Reverse Engineering · M
**Spec:** main spec 8.3, B14, A12, D13
- Tech fragments per faction (species); salvage and captured ships credit the loser's species.
- 100 fragments (70 for humans) unlock one of that faction's techs at 50% RP cost; human-adapted variants
  (cruder, sturdier, more dangerous) for some alien techs.
- Faction reactions: opinion event toward an empire using their tech (flattered or furious by personality).

### WP9: Espionage · M
**Spec:** main spec 12, D12 (agent coverage), E3 ("espionage caught" -30)
- Agents (cost, cap per empire) placed in a foreign empire; missions: gather intel (core systems at intel 2,
  raises intel level), steal tech fragments, sabotage convoys, incite unrest.
- Counter-intelligence on own worlds; caught agents trigger the opinion event.
- All numbers in a new `espionage_rules` Def, proposed at the WP.

### WP10: Research Pact, Intel Sharing, Tech in Deals · S
**Spec:** E4, E6
- Research pact (+10% research in shared branches) and intel sharing (shared coverage and intel levels;
  break = intel purge). Defence pact and alliance gates back to the E4 values.
- Techs as deal items (value RP cost x 0.5; AIs refuse their top-tier techs to rivals).

### WP11: AI Research, Intel & Espionage · L
**Spec:** E11, E12, D10, D12 ("the AI obeys fog")
- Research priorities by personality and situation; tier designs adopted as they unlock.
- The AI reads only its knowledge model under fog (targets, threats, war planning); scouts and listening
  posts to fill gaps.
- Refits against the enemy profile it knows; agents and missions; accepts and offers the new treaties.

### WP12: Research & Intel UI · L
**Spec:** F13, F map mode 4, F4, F10, F11, F14, F15, F18 provenance
- Research Tree screen (full screen; slots with ETA, search, "path to", fragment bars per faction).
- Intel / Fog map mode: knowledge levels, coverage, ghosts with age; unknown contacts as "?" until intel 2.
- Refit picker (fleet panel), designer "vs known enemy" with honest uncertainty, battle report estimates,
  diplomacy power estimates, espionage tab, fog setting in match setup.
- Loc keys; keyboard-navigable.

### WP13: Player Controls Audit · S
- Every M5 sim feature reachable by a human (owner rule: no AI-only features): research, refits, agents,
  listening posts, new treaties, tech deals. Fix gaps found by playing a match as the player.

### WP14: Testing, Balance & Performance Pass · L
**Spec:** B14 timings, B20, A14, E16, M4 DoD bars
- Unit tests for WP1-WP13 and repair of M1-M4 tests broken by the M5 changes.
- New research harness: tier timings against the B14 table (tier 1 in 4-6 months ... tier 5 about 3 years).
- Economy, combat and diplomacy harnesses back to their accepted levels with research and fog on.
- Huge galaxy performance with fog: 8x >= 60 fps, worst hour < 50 ms.
- Full determinism run (20 seeds x 4 sizes x 60 months) with the research, knowledge and intel checksums.

---

## D2. Dependency Order

| WP | Needs |
|---|---|
| WP2 | WP1 |
| WP3 | WP1 (gating works from WP2) |
| WP4 | WP1 |
| WP5 | WP4 |
| WP6 | WP5 |
| WP7 | WP2, WP3 |
| WP8 | WP2 |
| WP9 | WP6 |
| WP10 | WP2, WP6 |
| WP11 | WP2-WP10 |
| WP12 | WP2-WP10 |
| WP13 | WP12 |
| WP14 | everything |

## D3. M5 Definition of Done

- [ ] All WP acceptance criteria met.
- [ ] `tools/run_tests.sh` green; determinism harness green (20 seeds x 4 sizes, with research, knowledge
      and intel checksums).
- [ ] Research harness: tier timings within the B14 table at Standard pace.
- [ ] Economy harness at least at the accepted level (65 of 80); combat harness at the A14 targets;
      diplomacy harness at the E16 targets, all with fog on.
- [ ] Huge galaxy, 8 AI empires at year 15 with fog on: 8x speed holds >= 60 fps; worst hour under 50 ms.
- [ ] No spec numbers in code (data only); content validation green (tree checks included).
- [ ] Sim lint green; every player-facing string uses a loc key; all M5 screens keyboard-navigable.
- [ ] Every M5 feature usable by a human player (WP13).
- [ ] Spec change logs updated with every decision made during the build.

## D4. Open Questions (to settle at the WP, recorded in the change logs)

The specs give no number or rule for these; the WP proposes a placeholder and asks before relying on it.
1. **Tech list** (WP1): the ~100 techs, their effects and unlocks; species nodes; starting techs.
2. **Mk II/III slot layouts** (WP3) per class, and their cost and hull steps.
3. **Intel rates** (WP6): gain per source, decay, how battles carry a partial profile forward.
4. **Refit time and cost** (WP7), and whether a Mk change can be a refit.
5. **Human-adapted variants** (WP8): which alien techs get one and how they differ.
6. **Espionage numbers** (WP9): agent cost and cap, mission success and detection, effects.
7. **AI under fog** (WP11): how much the AI may remember from stale knowledge; whether Cadet-Officer AIs
   get any intel help.
8. **Research pact "shared branches"** (WP10): branches both empires have a tech in, or all branches.
