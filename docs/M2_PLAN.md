# DEATHWORLDERS — M2 Build Plan: Economy & Logistics

*Version 0.1 (2026-10-01). Turns main spec 4–6, 13, 19 (M2), Sub-spec B and the M2 parts of Sub-specs D and F
into an ordered build plan. Builds on M1 (docs/M1_PLAN.md); same rules (CLAUDE.md), same tooling.*

**Change log**
- 2026-10-01: plan created. Scope decisions below agreed with the project owner.
- 2026-10-01 (WP1): placeholders where Sub-spec B has no number, for the balance pass (WP14) to tune:
  freighter build days (Light 30, Heavy 60); colony ship speed 5 lane units/day; station upgrade build days
  scale like cost (×2 / ×4); shipyard and depot stockpile caps 1,000 / 2,000 / 4,000; outposts give 1 lane
  of supply range (D2 "extends supply range"). Breadbasket and Bastion have no named effect in M2 (no number
  in B4 / needs M6). Templates are generated per focus pair from a fixed pattern (farm, primary, primary,
  secondary, …). An empty string in a Def reference field means "none".
- 2026-10-01 (WP2): rule numbers are data too: `economy_rules` (B3/B4/B17/B18 constants, one core Def that
  mods can patch), `planet_size` (B2 table; the galaxy generator now reads orbital slots from it) and
  `start` (B19 opening, applied to every homeworld). Colonies live in `MatchState.colonies` and get their
  own `economy` checksum part; empires carry a treasury. `MatchState.defs` is a runtime-only reference to
  the content (set on creation and load, never saved). Monthly totals are spread over the 30 days without
  drift; jobs produce in JobDef.priority order. Growth needs a strictly positive monthly food net.
  Strikes pick the offline building on the `events` stream; revolts (B18 < 5) wait for M6 ground forces.
- 2026-10-01 (WP3): construction draws today's share of materials from the **site's own stockpile**: the
  colony for buildings, the station for stations and upgrades. A new station is a site with an empty
  stockpile that freighters fill (WP5/6); nothing moves between stockpiles for free. One building at a time
  per colony; one build per station. Cancelling refunds the materials used so far. Outposts may be placed in
  unclaimed systems and claim the system when finished (influence cost in WP8). The start (StartDef) adds
  B19's orbitals: Logistics T1 and Shipyard S at the capital, three belt Mining Stations; a homeworld system
  without an asteroid belt gets one (fair starts). B19's Listening Post waits for M5. Mining focus boosts
  same-system stations +250 permille (B11) at Primary, half at Secondary.
- 2026-10-01 (WP4): shipyards hold a ship queue; the first `docks` entries build in parallel from the
  shipyard's own stockpile. `shipyard.build_speed` (Industrial focus) shortens the build, rounded up. A colony
  ship takes its pop on completion from an own colony in the system (the orbited planet first) and holds the
  dock until one can spare it. Freighters get a berth at a hub in their system (logistics stations, then
  colonies with planet.freighter_berths); without one they're idle. Rebasing is an assignment change (the
  freighter flies there on its next job). Placeholder `core:hull/scout` (30 alloys, 30 days, 12 lane units/day);
  B19's starting ships: 3 Light Freighters, a Scout and a Colony Ship. Fuel upkeep is WP9's.
- 2026-10-01 (WP5): colonies and stations are "holders" in one ID space. In-system travel (B7) is 1 day to a
  body's own orbit or moon, otherwise 2 + (orbit-radius gap / 20) days, clamped 2-8. This matches Sol's
  Earth-Mars 3 and Earth-Belt 4 but gives Earth-Jupiter 6 instead of B7's 8 (the sim has no orbital
  angles). Freighters arriving by lane are placed at their target body (no extra impulse leg). Manual routes
  take whatever the source has (reserves apply to auto-logistics, WP6); cargo that doesn't fit stays aboard;
  an empty source means a day's wait and retry. Routes get their own `logistics` checksum part.
- 2026-10-01 (WP6): auto-logistics follows B8's order exactly. Every active build (colony queue head, station
  build, shipyard docks) is an implicit Normal-priority demand for its remaining materials, so construction
  sites feed themselves. Auto trips are one-shot jobs (freighter goes home after unloading). Source distance:
  in-system impulse days, otherwise 1000 + lanes; freighter distance: lanes x 100 + impulse days. The default
  reserve (200 permille of cap) and the colony-hub range (3 lanes; B8 only gives station tiers) are
  `economy_rules` data. B20's "half the freighters -> ~70% efficiency" is checked by the WP13 harness.
- 2026-10-01 (WP7a): the capital anchors the Core Sector at match start (range 3 lanes). Other hubs: a
  Logistics Station with `sector_range` (T2 3, T3 5) or a colony with Logistics as Primary (3). Sector cap 2
  (D3's starting value; no techs in M2). Membership and reach are recomputed monthly; reach bands (D9) add
  upkeep to buildings and stations and lower stability. Stage promotion needs age (5 years) only once:
  Developed/Core planets drop back only on pops or stability. Earth starts Core but drops to Developed
  until its stability reaches 60 (B19's opening sits at 55). Governor actions run inside the sim through the
  same functions the commands use. Balanced directive's best fit is a placeholder: ore/RE deposits ->
  Mining/Industrial, habitability >= 800 -> Farming/Research, else Research/Economy. All D2/D3/D9 numbers
  are `economy_rules` data.
- 2026-10-01 (WP7b): the Core Sector's hub is the capital's Logistics Station when it has one (B19 does), so
  the sector stockpile isn't the capital's own; a `core` flag gives it the Core range regardless of tier.
  Governor demands are derived daily, never stored, and only draw on sources inside the sector: each
  non-Manual colony keeps 2 months of job inputs and 3 months of food (Critical under 1 month); the hub
  gathers the sector's mining output (only from the producing stations, up to 50% of its cap, Low). Exports:
  a non-core hub sends its quota (default 50%) of surplus above reserve to the Core hub. Import requests are
  computed (not stored); approving one places a Critical player demand any source can fill.
- 2026-10-01 (WP8): a colony ship ordered to a planet flies there and lands (1 pop, stage Colony); it may
  target own or unclaimed systems, not orbital-only or uninhabitable bodies. Every new system claim costs D9's
  influence (outposts pay when placed and are refunded if cancelled; colonising an unclaimed system pays and
  claims when ordered). Empires start with no influence (B16 3/month), so the first claim comes around month 8;
  Mars-style colonies inside owned systems need none. New colonies: 5 credits upkeep until their first Farm,
  +100% growth for 5 years; homeworlds are backdated so they aren't "new". The payback estimate is a
  placeholder (colony ship value / (pops x (tax + ~4 credits) - upkeep)) for the colonise screen.
- 2026-10-01 (WP9): fuel is the hull's fuel upkeep (B6 for freighters), drawn monthly from the nearest own
  stockpile in supply range (owned planet 1 lane per B12, stations by `supply_range`: outpost 1, depot 2/3/4).
  Out of fuel: half speed until a later draw succeeds. Moving-warship fuel (B12 by size) and attrition come
  with M3.
- 2026-10-01 (WP10, agreed with the owner): pirates are frontier-only in M2: only own systems at reach >= 3
  roll D9's monthly chance, and at most 3 raiders hunt one empire (both data). Security (D9, M2 terms) = 20 +
  5 per garrison company + station `security` (0 until platforms/listening posts), halved at reach 7+.
  Raiders (owner -1, a non-playable faction) move monthly toward the frontier neighbour with the most of their
  target's freight, may found a base (10%/month) that sends out a raider every 6 months, and otherwise leave
  after 6 months. A freighter rolls once per passage through a raider's system (B9: 500 permille at sensor 50);
  detected = lost with its cargo (logged per empire, last 50). No escorts or captures until M3/M4.

---

## Goal of M2

A match where every empire runs a physical economy:
- planets with **pops, jobs, buildings, dual focus, stability and growth**; local **stockpiles** in milli-units,
- **stations** (outposts, mining, logistics hubs, shipyards, supply depots) built from delivered materials,
- **freighters** that physically carry goods along lanes, by **manual routes** and **auto-logistics** (demand targets),
- **sectors** with directives, templates and two-tier logistics, run by a built-in default governor,
- **colonisation** (colony ships, outposts with influence claim costs, colony stages),
- **credits, research and influence** accruing globally; upkeep and deficits,
- **fuel supply** for moving units, **pirates** raiding convoys on low-security frontiers,
- the same automation running every non-manual planet and every AI slot,
- the M2 UI from Sub-spec F20: planet panel, sector screen, logistics manager, stockpile view, colonise screen, alerts,
- and a headless **economy harness** checking the B20 balance targets, with the determinism harness still green.

No warships, combat, diplomacy, tech tree or species signature mechanics yet.

## Scope decisions (2026-10-01)

| Question | Decision |
|---|---|
| Sectors without leaders | **Sectors, no leaders.** Hubs, directives, templates, two-tier logistics, Sector screen. Each sector runs on a built-in **default governor** (no leader, no −100‰ penalty) until leaders exist. |
| What shipyards build | **Civilian ships only:** freighters (Light, Heavy) and colony ships. Warship hulls come with M3. |
| Who drives non-player empires | **Shared automation** (D10 operational layer + a simple expansion rule) for every non-manual planet and every AI slot. The M4 AI builds on it. |
| Pulled forward into M2 | **Influence & claims** (B16, D9), **research accrual** (B14, points only, no tree), **pirates & raiding** (B9, D9; pirates only), **fleet supply** (B12 fuel for the units that exist). |

## Not in M2 (deferred)

Warships, fleets, combat, escorts, patrols (M3) · leaders and governor traits · tech tree and research spending (M5) ·
trade stations and deals (B15) · species job traits and signature mechanics (M4) · migration and refugees ·
Core buildings (D8) and planet character traits (D11) · fog of war (D12) · warp/jump travel · ground forces.
Pirate bases can't be destroyed until M3 brings warships.

---

## D1. Work Packages (in build order)

Size: **S** ≈ one focused session, **M** ≈ 2–3 sessions, **L** ≈ 4+ sessions.

### WP1: Economy Defs & Core Data · L
**Spec:** B1–B6, B10–B11, D3–D4, C3

- New Def types: `JobDef`, `BuildingDef`, `FocusDef`, `SynergyDef`, `StationDef` (tiers), `DirectiveDef`,
  `TemplateDef` (ordered build list + job mix per focus pair and size).
- `HullDef` gains civilian roles: freighter (capacity, speed in lane units/day, berth use) and colony ship.
- Core data: all B3 jobs/buildings, B4 foci + 5 synergies, M2 stations (Outpost, Mining, Logistics T1–T3,
  Shipyard S/M/L, Supply Depot), Light/Heavy freighter, colony ship, 7 directives, templates for every focus pair.
- **Pace scaling** helper (B0): costs and build times × pace permille.
- Validation for the new references (jobs ↔ buildings ↔ foci ↔ templates).

**Acceptance:** core loads with zero errors; every B-table number is in data, not code.

### WP2: Colonies, Pops & Planet Economy · L
**Spec:** B0, B2–B5, B13–B18, main spec 13

- `Colony` state on owned planets: pops (species, count), job assignment, buildings, focus primary/secondary,
  retooling timer, stability, growth points, stage.
- `Stockpile` (milli-units, per-resource caps, overflow lost) on planets and stations.
- Day tick: job output (inputs drawn locally; short input scales output proportionally), construction draw.
  Month tick: food consumption, growth (B17), stability (B18 subset: food, unemployment, retooling, deficit,
  reach), taxes and upkeep, influence and research accrual into the **empire treasury**.
- Auto job assignment (D4: food first if starving, then focus jobs, then others).
- Starting economies: Sol per B19; standard homeworlds get an equivalent opening.

**Tests:** B19 monthly flow reproduced within ±1 unit; proportional input shortage; starvation path; growth.

### WP3: Construction & Stations · M
**Spec:** B10–B11, main spec 5

- Planet building queue and station construction/upgrade in orbital slots; materials drawn **daily** from the
  local stockpile; construction pauses (never fails) when dry.
- Mining stations produce into their own stockpile (B11 by location, Mining focus +250‰).
- Commands: `queue_building`, `queue_station`, `upgrade_station`, `cancel_construction`, `set_focus`.

**Tests:** a build pauses and resumes with deliveries; pace multiplier scales cost and time.

### WP4: Shipyards & Civilian Ships · M
**Spec:** B6, B10

- Shipyard docks (T1 1 / T2 2 / T3 3), size limits, one build per dock, daily consumption.
- Freighters and colony ships as units with upkeep (credits + fuel); freighters bound to a hub **berth**
  (B6 berths; freighters without a berth sit idle).
- Commands: `queue_ship`, `rebase_freighter`.

### WP5: Freighters & Manual Routes · L
**Spec:** B6–B8 (manual), main spec 6.3

- In-system positions for stockpiles (planet / station orbit) and impulse travel days (B7); lane travel at the
  freighter's lane units/day; load/unload 1 day each.
- Manual routes (source → destination, resource, amount per trip, priority) with freighters looping.
- Throughput formula (B7) as a shared helper for the UI.
- Commands: `create_route`, `edit_route`, `delete_route`, `assign_freighters`.

**Tests:** a Belt → Earth route moves ~300 ore/month with one Light freighter (B19).

### WP6: Auto-Logistics & Demand Targets · M
**Spec:** B8, D5

- Demand targets and reserves (default 20% of cap); the B8 assignment algorithm each day tick, exactly as
  specified (sort keys and tie-breaks), with hub range by tier.
- Commands: `set_demand_target`, `set_reserve`.

**Tests:** half the needed freighters → ~70% efficiency, not collapse (B20).

### WP7: Sectors, Directives & Templates · L
**Spec:** D2–D5, D9 (reach)

- Sector hubs (Logistics Station T2+ or Logistics-focus planet), membership by lanes, sector cap, the capital's
  Core Sector; **reach** per system with its upkeep/stability penalties.
- Default governor: picks templates by directive and focus pair, queues buildings, sets focus at Developed.
  Planet autonomy Automated / Assisted / Manual (Automated by default, D1).
- Two-tier logistics: local freight by auto-logistics inside a sector; trunk routes, export quotas (default
  50%) and import requests between sectors.
- Colony stages Outpost → Colony → Developed → Core (D2).
- Commands: `create_sector`, `set_directive`, `set_autonomy`, `pin_template`, `set_export_quota`,
  `approve_import`.

### WP8: Colonisation & Claims · M
**Spec:** B10 colony ship, B16, B17, D2, D9

- Colony ship takes 1 pop; `colonise` command; new colony upkeep 5 credits + food until its Farm completes;
  +100% growth for 5 years.
- Outposts claim systems; influence claim cost `25 × (1000 + owned_systems × 60) / 1000`.
- Payback estimate helper for the colonise screen (D9).

### WP9: Fuel & Supply · S
**Spec:** B6 upkeep, B12

- Fuel drawn monthly by freighters (B6) and moving units (B12 sizes) from the nearest stockpile in supply range
  (owned planet 1 lane; Supply Depot 2/3/4).
- Out of fuel: the unit moves at half speed until resupplied (M2 rule; M3 adds attrition for warships).

### WP10: Security & Pirates · M
**Spec:** B9, D9

- System security (D9 formula, M2 terms: base, platforms/posts once built, reach penalty).
- Monthly pirate roll on the `events` stream; pirate raiders (a non-playable pirate faction) hunt lanes with
  freight traffic; detection roll per freighter passage (B9); unescorted freighters destroyed or captured.
- Pirate bases spawn and persist (destroyable from M3). Losses go to a per-empire log.

### WP11: Autopilot (Shared Automation) · M
**Spec:** D1, D10

- Every AI slot and every Automated planet runs the default governor, auto-logistics and a simple expansion
  rule (outposts and colonies by habitability, deposits and reach; freighters when utilisation > 95%).
- All decisions inside the sim on the `ai` stream, monthly; same Commands as the player.

### WP12: Economy UI · L
**Spec:** F4, F6–F9, F12, F20

- Top bar: credits, research, influence (with monthly net).
- Planet panel (F4), Sector screen (F6), Logistics Manager (F7: trunk routes, demand targets, hubs &
  freighters, losses), Stockpile view (F9 table), Colonise screen (F8), Alerts panel (F12 + the D6 alerts that
  exist in M2, each with a one-click Command fix).
- Map: freighter diamonds on lanes, station markers in the tactical scope.
- Keyboard-only navigation and loc keys as in M1.

### WP13: Economy Harness · M
**Spec:** B20

- `tools/economy_harness.gd`: autopilot empires for 50 in-game years across seeds; resource curves, freighter
  utilisation, time to milestones (first colony, colony count, freighters, alloys/month) vs the B20 targets.
- Determinism harness extended with `economy` and `logistics` checksum parts.

### WP14: Balance Pass · S–M
**Spec:** B20, B21

- Tune data (not code) until the harness meets B20 across seeds; record changes in Sub-spec B's change log.

---

## D2. Dependency Order

| WP | Needs |
|---|---|
| WP2 | WP1 |
| WP3 | WP2 |
| WP4 | WP3 |
| WP5 | WP4 |
| WP6 | WP5 |
| WP7 | WP6 |
| WP8 | WP4 (colony ships), WP3 (outposts) |
| WP9 | WP5 |
| WP10 | WP5 |
| WP11 | WP7, WP8 |
| WP13 | WP9, WP10, WP11 |
| WP14 | WP13 |

WP12 (UI) grows alongside: planet panel with WP2–3, logistics manager and stockpile view with WP5–6, sector
screen with WP7, colonise screen with WP8, alerts last.

## D3. M2 Definition of Done

- [ ] All WP acceptance criteria met.
- [ ] `tools/run_tests.sh` green; determinism harness green (20 seeds × 4 sizes, with economy checksums).
- [ ] Economy harness meets the B20 targets on at least 18 of 20 seeds.
- [ ] Huge galaxy, 8 autopilot empires, year 15: 8× speed holds ≥ 60 fps; a month tick under 50 ms headless.
- [ ] No B-table numbers in code (data only); content validation green.
- [ ] Sim lint green; every player-facing string uses a loc key; all M2 screens keyboard-navigable.
- [ ] Spec change logs updated with every decision made during the build.

## D4. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Daily tick cost with hundreds of colonies and freighters | Profile from WP2; cache job/modifier sums with dirty flags (C4); iterate IdMaps once per tick |
| Auto-logistics oscillation (freighters chasing each other) | Count in-transit cargo in deficits (B8); reserves; harness tracks wasted trips |
| Rounding drift in milli-unit stockpiles | Floor everywhere, per B0; tests compare monthly totals to B19 |
| Scope creep into combat | Pirates only; no escorts or battles in M2 |
| UI volume (six screens) | Build screens with the WP they display, not all at the end |
