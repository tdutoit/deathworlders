# DEATHWORLDERS — Sub-spec D: Scale, Expansion & World Mechanics

**Change log**
- 2026-10-01 (M2 WP12): D6 alerts are derived from the state when shown (`ui/alerts.gd`), with no alert
  history, so the time-based triggers use what the state records: Starvation = food runs out within 90 days
  at last month's rate (fix: a Critical food demand for 3 months of the shortfall); Construction stalled =
  14+ stalled days (fix: a Critical demand for the rest of the missing resource); Shipyard idle = an empty
  queue now (fix: queue a Light Freighter); Freighter shortage = over 95% of freighters busy now (fix: queue
  a Light Freighter at the first yard that can); Convoy lost = a loss in the last 30 days; Unemployment >= 2
  (fix: queue the template's next building); Stability < 30; Stockpile overflow >= 90% of cap; Frontier
  unrest = raiders hunting the empire; Supply warning = a ship out of fuel; plus a Credit deficit alert.
  Muting is not in M2.

*Version 0.1. Companion to the main Game Design Spec v1.1 and Sub-specs A–C. Numbers are starting values at Standard pace, in the integer conventions of Sub-spec A0.*

**Goal:** a 60-planet empire should be *less* work per planet than a 6-planet empire, without removing meaningful choices. Expansion should be a real investment with visible costs, not a free snowball.

---

# PART 1: MANAGING AT SCALE

## D1. Design Rules

1. **Decide at the right altitude.** The player sets *direction* (sector directives, trunk routes, focus); the game handles *execution* (buildings, jobs, local freight).
2. **Automation is opt-out, never opt-in.** New colonies are automated by default; the player takes manual control where they care.
3. **Management by exception.** The game interrupts only when a decision is needed.
4. **One system for players and AI.** Governors, templates and auto-logistics are the same code the AI uses (D10).

## D2. Colony Stages

| Stage | Entry condition | Player decisions | Automation |
|---|---|---|---|
| **Outpost** | Outpost station built | None | Claims system, extends sensor & supply range |
| **Colony** | Colony ship lands | None | Governor/default template builds Farm + Mine; +100% growth (B17) |
| **Developed** | ≥ 5 pops **and** ≥ 5 years since founding | Primary & Secondary focus (or accept the sector directive's default) | Template for chosen focus pair |
| **Core** | ≥ 15 pops, stability ≥ 60, within 2 lanes of a sector hub | One **Core building** (D8) | Full template |

A planet can drop a stage if it loses pops or stability (Core → Developed), which gives the player a reason to protect key worlds.

## D3. Sectors & Governors

- A **sector** is a group of systems anchored on a **Sector Hub**: a Logistics Station T2+ or a Logistics-focus planet designated as hub.
- Systems join the sector of the nearest hub within **3 lanes** (T2 hub) / **5 lanes** (T3 hub). The capital system anchors the **Core Sector** from turn one.
- **Sector cap:** 1 (Core) + 1 per Society tech tier reached + 1 per 2 Logistics techs. Starting value: 2.
- Each sector needs a **Governor** (a leader). No governor = the sector runs on default rules at −100‰ output.

### Directives (one per sector)
| Directive | Default focus pairs for new Developed planets | Build priority |
|---|---|---|
| Balanced | Best fit per planet (by deposits/habitability) | Housing, food security, then focus |
| Industrial Core | Industrial + Mining, Industrial + Logistics | Foundries, fabricators, shipyards |
| Breadbasket | Farming + Logistics | Farms, dockyards, growth |
| Research | Research + Economy | Labs, academies |
| Frontier Growth | Farming + Mining | Cheap buildings, outposts, colony ships |
| Military March | Military + Fortress | Barracks, defence platforms, supply depots |
| Fortress Line | Fortress + Military | Fortifications, interdictors, listening posts |

### Planet autonomy (per planet)
- **Automated** (default): governor decides everything within the directive.
- **Assisted:** governor queues suggestions; the player approves in one click.
- **Manual:** full player control; the governor ignores it.

### Governor traits (examples)
*Logistician* (+20% freighter throughput in sector) · *Builder* (−15% building cost) · *Populist* (+5 stability) · *Frontiersman* (reach penalties halved, D6) · *Corrupt* (−10% credits, but +10% output).

## D4. Planet Templates

- A **template** is an ordered build list for a planet's slots, plus a target job mix, tagged with a focus pair and size range.
- Core ships templates for every focus pair; players create, edit, save and **share** them (same export-code format as ship designs, Sub-spec C5).
- Governors pick the template matching the planet's focus pair and size; the player can pin a specific template.
- Jobs are **always auto-assigned** by priority: food first if starving, then focus jobs, then others. Players can set per-planet job priorities but never assign individual pops.

## D5. Two-Tier Logistics

| Tier | Who manages | What |
|---|---|---|
| **Trunk** (between sectors) | Player | Routes between sector hubs, and export quotas |
| **Local** (within a sector) | Governor via auto-logistics (B8) | All freight between the sector's planets, stations and hub |

- Each sector hub keeps a **sector stockpile**.
- **Export quotas:** the player sets, per sector and resource, what share of surplus flows up the trunk, e.g. "Kepler Sector: export 60% of alloy surplus to Sol." A default quota of 50% applies.
- **Import requests:** a sector short on something (e.g. a new colony sector needing alloys) raises a request that shows as an alert; the player approves a trunk shipment in one click.
- Fleets draw supply from the nearest hub's stockpile (B12 unchanged).

## D6. Management by Exception: Alerts

Alerts are sorted by urgency. Each has a **one-click fix**, which issues a normal Command.

| Alert | Trigger | One-click fix |
|---|---|---|
| Starvation forecast | Food hits 0 within 90 days at current rate | Route food from nearest surplus |
| Shipyard idle | Shipyard with no queue for 30 days | Queue last design / open designer |
| Construction stalled | Missing materials for 14+ days | Create import request |
| Stockpile overflow | ≥ 90% cap | Raise export quota / add freighter |
| Freighter shortage | Hub utilisation > 95% for 30 days | Queue 2 freighters at hub |
| Convoy lost | Freighter destroyed | Reroute / assign escort |
| Unemployment | ≥ 2 unemployed pops | Queue template's next building |
| Stability falling | Below 30 | Show causes; suggest garrison/amenity |
| Supply warning | Fleet out of supply range | Show nearest depot / queue depot |
| Frontier unrest | Pirate activity spawned (D9) | Assign patrol |

Alerts can be muted per type or per sector.

## D7. War Footing

One empire-wide lever, instead of refocusing dozens of planets.

| State | Alloys (Workers) | Munitions | Credits (Clerks) | Research | Stability | Other |
|---|---|---|---|---|---|---|
| **Peace** | +0 | +0 | +0 | +0 | +0 | — |
| **Mobilised** | +200‰ | +500‰ | −300‰ | −200‰ | −5 | Army recruit −25% cost |
| **Total War** | +400‰ | +1000‰ | −500‰ | −400‰ | −15 | War weariness gain ×0.5 (Humans ×0.35) |

- Switching takes **60 days** of transition (half the bonus during it).
- Switching back to Peace from Total War causes a 6-month −5 stability "demobilisation" dip.
- Humans (Stubborn) accumulate war weariness slower in Total War: the HFY "we don't quit" identity.

---

# PART 2: EXPANSION COSTS

## D8. Why Expand, Why Build Tall

**Expansion pays** through deposits, housing, strategic chokepoints, and more hubs.
**Building tall pays** through **Core buildings** (one per Core planet):

| Core building | Effect |
|---|---|
| Orbital Ring | +1 orbital slot, shipyard build speed +25% |
| Grand Academy | +30 research, leader XP +50% in sector |
| Arsenal Complex | Munitions +50% sector-wide, armies recruit at Regular veterancy |
| Planetary Exchange | +25 credits, trade range +2 lanes |
| Bastion Core | Fort level 5, planetary shield vs bombardment |
| Genesis Vault | Pop growth +50% sector-wide |
| Deep Space Array | Sensor range +3 lanes (see D12) |

## D9. Costs of Going Wide

### Reach (distance from a hub)
Each system's **reach** = lanes to the nearest own sector hub (or capital if unsectored).

| Reach | Effect on that system |
|---|---|
| 0–2 | None |
| 3–4 | Upkeep +100‰, stability −5 |
| 5–6 | Upkeep +250‰, stability −15, cannot reach Core stage |
| 7+ | Upkeep +400‰, stability −25, security −50% (D10) |

This pushes players to build hubs as they expand, which ties expansion directly to the logistics game.

### Escalating claim cost
```
outpost_influence = 25 * (1000 + owned_systems * 60) / 1000
```
10 systems → 40 influence; 30 → 70; 60 → 115. Alloy cost stays at 80 (B10).

### Colonies are investments
- Colony ship takes 1 pop from the source world (B10/B17).
- New colony upkeep: 3 credits/month + food until its Farm completes (WP14; was 5, see Sub-spec B change log).
- A typical colony pays back its cost in **5–10 years**; the colonise screen shows an estimated **payback date** based on the planet and the sector directive.

### Frontier security and pirates
Each system has **Security** (0–100):
```
security = 20 base
         + 15 per own warship formation patrolling
         + 10 per defensive platform / listening post
         + 5 per garrison company
         − reach penalty (D9 table)
```
- Systems with security < 30 roll monthly for **pirate activity**: `chance = (30 − security) * 10 ‰`.
- Pirates spawn raiders that hunt convoys (B9) and may build a **pirate base**. Destroying a base gives salvage (D14) and removes it.
- The Ohlan Consortium can *hire* pirates; Krothi swarms suppress them; Thessari gain security from treaties.

---

# PART 3: AI

## D10. AI Uses the Same Automation

The AI is split into two layers:

| Layer | Implementation |
|---|---|
| **Operational** (planets, local logistics, building) | The same governors, directives, templates and auto-logistics players use (D3–D5) |
| **Strategic** (expansion targets, trunk routes, war footing, fleets, diplomacy) | AI personality weights from `SpeciesDef` + utility scoring on each monthly tick |

- Building the automation well gives the AI competence for free, and every AI bug found improves player automation too.
- The AI obeys fog of war (D12) on Normal and below; higher difficulties can grant intel bonuses (openly listed in match setup).
- All AI decisions run inside the sim on the `ai` RNG stream (deterministic).

---

# PART 4: NEW WORLD MECHANICS

## D11. Planet Character Traits

Planets earn **character traits** from their history. They produce emergent stories ("Mars held for 200 days; it's been *Unbroken* ever since").

- Max **3 traits** per planet; a new trait beyond that replaces the oldest *minor* trait.
- Traits are **permanent** unless an event removes them.
- Each trait is a `PlanetTraitDef`: trigger (event DSL, Sub-spec C8) + modifiers. Fully moddable.
- The planet panel shows a **history timeline** of the events that created each trait.

| Trait | Trigger | Effect |
|---|---|---|
| **Unbroken** | Survived a siege ≥ 60 days without falling | Fort +1, garrison org +200, stability +5 |
| **Forgeheart** | Built 50 ships at its shipyards | Build speed +15% |
| **Cradle of Soldiers** | Deathworld or Arctic human colony with ≥ 10 pops | Armies recruited here start Regular, +10% attack |
| **Breadbasket of the Stars** | Exported 10,000 food | Growth +10% on planets it supplies |
| **Crossroads** | 100,000 cargo passed through its hub | +15 credits, freighter speed +10% in system |
| **Liberated** | Freed from enemy occupation | Stability +20, opinion +30 toward liberator |
| **Martyr World** | Fell after a Last Stand (A10) | When retaken: all traits restored, +Respect (Legend), Soldiers +50% |
| **Melting Pot** | 3+ species with ≥ 3 pops each | Research +10%, trade +10% |
| **Frontier Spirit** | Founded at reach ≥ 5, survived 20 years | Reach penalties halved on this planet |
| **Scarred** | Orbitally bombarded ≥ 90 days | Stability −10, but garrison attack +25% ("never again") |
| **Haunted** | ≥ 5 pops lost in one event (plague, invasion) | Stability −5, Xeno Studies research +15% |
| **Mutinous** | Revolted twice | Stability −10 until 10 years of peace |

Species-specific traits come via species event packs (e.g. Krothi *Brood Nest*, Vess'kar *Old Archive*).

## D12. Fog of War (knowledge model)

Fog is **part of the sim state**: each empire has a **knowledge model** that the UI and the AI both read. That makes it deterministic and lets the AI play fair.

### Knowledge levels per system (per empire)
| Level | You know | Shown as |
|---|---|---|
| **Unknown** | Nothing | Black, lanes only if adjacent to known space |
| **Explored** | Star, planets, deposits, lanes; ownership **as last seen** | Dimmed, "as of <date>" |
| **Covered** | Live: ownership, presence of fleets/convoys | Full colour |

Contact-level detail (ship classes, loadouts) still uses the **intel levels 0–4** from main spec 7.5.

### Sensor coverage
| Source | Coverage |
|---|---|
| Owned planet / outpost | Own system |
| Listening Post | 2 / 3 / 4 lanes (T1/T2/T3) |
| Fleet / scout | Own system (scouts +1 lane) |
| Deep Space Array (Core building) | +3 lanes |
| Allied shared vision (treaty) | Ally's coverage |
| Espionage agent | Target empire's core systems at intel level 2 |

### Detection contest
```
detected if  sensor_strength ≥ signature − stealth
signature: S 20 · M 40 · L 70 · XL 100; freighters 30
```
- ECM and stealth tech reduce signature; late-game cloaking.
- **Warp charge-ups** (main spec 3.4) add +60 signature for 2 days: listening posts see them coming.
- Pirates and Ohlan ships have innate stealth.

### Ghosts & stale info
- Contacts that leave coverage become **ghost markers** with their last-known size and a timestamp, fading over 90 days.
- Other empires' **military power** is shown as an estimate with error bars that shrink with intel level ("~40–70 ships").
- Battle reports under low intel give **estimated** enemy losses ("est. 4–6 ships destroyed").

### Gameplay consequences
- **Convoys are invisible** to enemies outside their coverage, so raiding requires scouting or listening posts.
- Exploration matters again mid-game: stale ownership data can be wrong.
- Surprise attacks (Sub-spec A3 ambush rule) come naturally from coverage gaps.

### Multiplayer note
With lockstep, every client holds the full state, so fog is enforced by the client UI. The knowledge model keeps honest clients honest and the AI fair; public competitive play would need server-side fog later (main spec 18.6).

### Performance
Coverage recalculated on **day ticks** (not hourly), incrementally when sources move or change.

## D13. Salvage Fields

Battles leave **debris fields**: new entities in the system.

### Contents (from destroyed ships, both sides)
```
alloys     = 20% of destroyed ships' alloy cost
components = 10% of destroyed ships' component cost
exotics    = 25% of destroyed ships' exotic cost
fragments  = per faction, half of the A12 tech-fragment formula
```
The victor receives the **other half** of the fragments immediately (Sub-spec A12 is split: half instant, half in the field).

### Harvesting
- **Salvage Tug** (new hull): 70 alloys, 10 components, 45 days; harvests **30 units/month** of mixed contents into its hold (capacity 150), then hauls to the nearest own stockpile.
- **Salvage Bay** (utility module for cruisers+): harvests 10 units/month while the fleet sits in the system.
- Harvested fragments go straight to research.
- Fields **decay 2% per month** and vanish at < 5% of original value.
- Anyone can salvage any field, including enemies and pirates, so fields in contested systems become **flashpoints**.

### Derelicts (HFY moment)
- Ships reduced below 10% hull whose side lost the battle have a 30% chance to become **derelicts** instead of being destroyed.
- A derelict can be **recovered**: tow with a Salvage Tug to a shipyard and repair for **50% of its build cost**. It joins your fleet as the original design, alien hull included.
- Recovered alien ships give +20 fragments per month while in service (reverse engineering by use). Humans: +50%.
- Aliens get an opinion hit when humans fly their own ships back at them.

### Graveyards
- Battles with ≥ 5,000 total destroyed hull cost create a **Graveyard** landmark: a large, slow-decaying field (0.5%/month) that fires events (salvage discoveries, ghost signals, memorials) and gives a small permanent sensor bonus to its owner (debris acts as a detection net).

---

## D14. Changes to Other Documents

| Document | Change |
|---|---|
| Main spec 4 | Colony stages (D2), Core buildings (D8) |
| Main spec 6 | Two-tier logistics, sector stockpiles, quotas (D5) |
| Main spec 11 | Governors become a key leader role (D3) |
| Main spec 17 | Fog of war setting now selects: Off / Standard (D12) / Hardcore (no ghosts, estimates only) |
| Sub-spec A12 | Tech fragments split half instant / half in the salvage field |
| Sub-spec B10 | Add Salvage Tug hull, Salvage Bay module |
| Sub-spec C3 | New Defs: `SectorDirectiveDef`, `PlanetTemplateDef`, `PlanetTraitDef`, `CoreBuildingDef`, `AlertDef`, `WarFootingDef`; new entities: Sector, SalvageField, Derelict, Ghost, KnowledgeModel |
| Milestones | Governors, templates, alerts land in **M2** (economy); fog/knowledge in **M5** (intel); salvage in **M3** (military); traits and war footing in **M7** (HFY layer) |

## D15. Balance Targets

- A 60-planet empire needs **≤ 2 player actions per in-game month** on average in peacetime with default automation (measured by the harness's action counter using a scripted "lazy player").
- Automated planets reach ≥ 85% of the output of a well-managed manual planet.
- A wide empire (60 systems) and a tall empire (20 systems, many Cores) score within ±15% on military/economy strength at year 50.
- Pirates are a nuisance, not a crisis: < 5% of convoy traffic lost in a moderately patrolled empire.
- Salvage should repay ~10–20% of a battle's losses for the side that holds the field.
