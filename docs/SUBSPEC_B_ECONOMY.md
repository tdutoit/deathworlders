# DEATHWORLDERS — Sub-spec B: Economy & Logistics Numbers

*Version 0.1. Companion to the main Game Design Spec v1.0 (sections 4, 5, 6, 8, 13). All numbers are **starting values** at **Standard pace**; the balance harness tunes them.*

**Change log**
- 2026-10-01 (M1 WP3) B1: `ResourceDef.base_value` is stored in milli-credits (Fuel 1.5 = 1500, Food 1 = 1000);
  Research and Influence have base value 0. `stockpile_default_cap` is in whole units (B5: 500), 0 = uncapped.
- 2026-10-01 (M2 planning, agreed with the owner):
  - B4/B6: a Logistics-focus planet gives **+4** freighter berths (B4's "+2" corrected to match B6).
  - B10: shipyard size and tier are one upgrade path: T1 = S, 1 dock; T2 = M, 2 docks; T3 = L, 3 docks
    (upgrade cost ×2 / ×4 the base row).
  - B13: station upkeep (credits/month): Outpost and Mining stations 1; Logistics, Shipyard and Supply Depot
    T1 2, T2 4, T3 6.
  - Deposits: an extraction building needs a matching deposit on the planet (Mine: Ore, RE Mine: Rare Earths),
    and the deposit's richness (1–3) is how many of that building the planet can hold. Farms need no deposit.
  - B3: the Miner's "4 Ore (or 1 Rare Earth on RE deposit)" becomes two buildings: **Mine** (Miner, 4 Ore) and
    **RE Mine** (RE Miner, 1 Rare Earth, needs a Rare Earth deposit). Mining stations split the same way by
    location (belt ore / RE belt / moon or barren / gas giant refinery, B11).
  - B2: the capital building adds **+2** building slots (was +1), so B19's ten Earth buildings fit.
  - B19: Earth's starting stockpile adds **100 Rare Earths** (the Fabricator's input had no source).
  - B4: focus effects other than job output (growth, stockpile cap, berths, build speed) also apply at 50% for
    the Secondary focus.
- 2026-10-01 (M2 WP2, agreed with the owner): job assignment follows D4's default order (farmers first if
  starving, then the per-planet priority list, then Primary then Secondary focus jobs, then the rest by job
  priority), and each job can have a per-planet **cap**. The opening sets caps (Miner 2, Munitions Worker 1,
  Researcher 4) so every homeworld starts with B19's exact mix.
- 2026-10-01 (M2 WP14, balance pass part 1; numbers are tuning, not owner decisions):
  - B13: **taxes 1 credit per pop** (was 0.5; B19's opening income becomes 20 + 12 + 24 = 56). New-colony
    upkeep (D9) **3 credits** until the first Farm (was 5). With 0.5/pop every AI empire's upkeep (stations,
    freighters, buildings, young colonies) outran its income by year 6-8 and expansion stopped.
  - B8: auto-logistics skips a load smaller than `min_trip_permille` (250) of the freighter's capacity **and**
    smaller than half the demand's target, for every priority (Critical too: a 1-pop colony eating 1 food a
    month otherwise sent a freighter a day with 0.03 food). Construction demands are exempt (their target
    shrinks with the stock, so the last small load would never grow). A construction site's remaining
    materials are earmarked: never surplus for another demand. Auto jobs and routes avoid systems where a
    raider hunting the empire sits (B8 "avoid hostile systems"); freighters wait rather than enter one.
  - B10: a station takes construction materials from the stockpile of its owner's colony it orbits (orbital
    transfer), after its own; this breaks the "no freighter to build the first freighter" deadlock.
  - D4: on Automated planets the opening's job caps are dropped once any pop is unemployed.
  - Autopilot (AI only): expands (colonies, stations, ships) only with a positive monthly credit net, no
    deficit and 100 credits in hand; keeps 2 shipyards; upgrades or adds a logistics hub when no berth is
    free; runs the Core Sector on Industrial Core (Research while the credit net is under 5).
- 2026-10-01 (M2 WP14, balance pass part 2):
  - B3: job **inputs** come from the colony's stockpile, then from its owner's operational stations orbiting
    the same body (orbital transfer, as for construction): the Core hub over the capital feeds its Foundries.
    Before, 2,000-3,000 ore sat in stations while the capital's Foundries ran dry.
  - B8 route safety: no auto job on a leg that can't avoid raided systems; a loaded freighter whose
    destination gets cut off takes its cargo back to the source (it used to wait forever with it aboard, and
    20-30 freighters piled onto one cut-off site). Build demands now send a load under the minimum trip only
    when it finishes the site (the capital's thin surplus was split into 0.9-alloy trips to ten sites).
  - Autopilot: Research directive only when the credit net is low **and** the treasury is under 300; no new
    colony ship while 2 colonies are still under 3 pops.
  - Harness (5 seeds x 15 years, small, 4 AIs = 20 empires): alloys/month 50-147 (was 5-27), colonies 4-11,
    shipyards 2 everywhere, first colony by month 2-11. Ignoring freighters, 7 of 20 empires meet every B20
    target; the misses are alloys just under 60 (50-55) and colony counts of 4 or 11. Freighters 5-19 at
    0-63% utilisation: the AI buys one only above 95% use, and the economy doesn't need more at these
    sizes, so B20's 20-40 freighters is never reached (open question for the owner).
- 2026-10-01 (M2 WP14, balance pass part 3):
  - B17 "requires local food surplus", **provisional reading, owner to confirm**: a surplus is more food made
    than eaten this month **or** `food_buffer_months` (3) of what the colony eats on hand. With the strict
    reading, a colony that moved its farmers into Foundry/Mine jobs stopped growing for good (one sat at 5/10
    pops with 450 food stored).
  - Autopilot: only colonises a system within freight range of one of its hubs (colonies outside every
    hub's range waited 10+ years for a Farm that could never arrive, at full young-colony upkeep).
  - Harness (5 seeds): 2 of 20 empires meet every B20 target; 14 of 20 meet all but the freighter count.
    Freighters 7-21 at 0-100% use (mostly 25-70%). B19 puts a Light Freighter at ~300 units/month; a year-15
    small-map economy moves ~500/month, so 20-40 freighters would mostly sit idle. Proposed: B20's freighter
    band applies to Medium+ maps, or becomes "freighters >= 80% busy is a shortage" (owner to decide).
- 2026-10-01 (owner decisions):
  - B20: the year-15 freighter target is **logistics health, not a count**: over the last year freighters
    average at most 80% busy, with at most 3 months above 95% (the harness checks this).
  - B17: the stock reading above is **confirmed** (production surplus or a 3-month food buffer on hand).

---

## B0. Conventions

- Same integer rules as Sub-spec A (permille, floor division, summed modifiers, ID-ordered iteration).
- **Stockpiles are stored in milli-units** (1 unit = 1000) so daily accrual of monthly rates never loses fractions. Displayed as whole units.
- **Rates are defined per month.** The day tick accrues `rate * 1000 / 30` milli-units per day.
- **Month tick** settles: upkeep, pop growth, stability, influence, trade income, research completion checks.
- **Pace multiplier** (match setting) scales costs and build times: Fast 600‰ · Standard 1000‰ · Epic 1600‰.

---

## B1. Resources

| Resource | Type | Base value (credits) | Main source | Main sink |
|---|---|---|---|---|
| Food | Physical | 1 | Farmers | Pops (1/pop/month), armies |
| Ore | Physical | 1 | Miners, mining stations | Foundries, munitions |
| Rare Earths | Physical | 4 | RE deposits, belt stations | Components, advanced buildings |
| Alloys | Physical | 3 | Workers (foundries) | Ships, stations, buildings |
| Components | Physical | 8 | Engineers | Ships (mid+ hulls), stations T2+ |
| Exotics | Physical | 20 | Rare deposits, anomalies, salvage | Late tech ships, jump drives |
| Munitions | Physical | 2 | Munitions workers | Fleet ammo, armies |
| Fuel | Physical | 1.5 | Gas giant refineries | Fleet movement, freighters |
| Credits | Global | 1 | Clerks, taxes, trade | Upkeep, purchases, diplomacy |
| Research | Global | — | Researchers, stations | Tech |
| Influence | Global | — | Base, Council seats, relations | Treaties, claims, edicts |

Base values are used by trade, AI valuation, salvage and battle scoring.

---

## B2. Planets: Size, Slots, Housing

| Size | Building slots | Base housing (pops) | Orbital slots |
|---|---|---|---|
| Tiny | 2 | 6 | 1 |
| Small | 4 | 12 | 2 |
| Medium | 6 | 20 | 3 |
| Large | 8 | 28 | 3 |
| Huge | 10 | 36 | 4 |

- Effective housing = `base * habitability / 1000` (species-specific; humans ≥ 600‰ on Deathworld/Arctic/Desert with Deathworlder trait).
- Capital building adds +2 slots and +8 housing.

## B3. Jobs (per pop, per month, before modifiers)

| Job | Building (jobs) | Output | Input |
|---|---|---|---|
| Farmer | Farm (3) | 6 Food | — |
| Miner | Mine (3, needs Ore deposit) | 4 Ore | — |
| RE Miner | RE Mine (3, needs Rare Earth deposit) | 1 Rare Earth | — |
| Worker | Foundry (3) | 3 Alloys | 6 Ore |
| Engineer | Fabricator (2) | 2 Components | 1 Alloy, 1 Rare Earth |
| Munitions Worker | Munitions Plant (2) | 8 Munitions | 2 Ore |
| Refiner | Refinery (2, gas giant orbit) | 6 Fuel | — |
| Researcher | Lab (3) | 3 Research | — |
| Clerk | Exchange (3) | 4 Credits | — |
| Dockworker | Dockyard (2) | +2 freighter berths, +100 stockpile cap each | — |
| Soldier | Barracks (3) | Garrison +1 company-equivalent; recruitable | 1 Munitions |

- **Inputs are taken from the local stockpile.** If an input is short, output scales down proportionally (no global rescue).
- **Unemployed pops** give 1 credit (tax only) and −10 stability each.
- **Taxes:** every pop pays 1 credit/month (WP14; was 0.5).

## B4. Planet Focus

- **Focus bonus = +500‰** output for the jobs matching the focus.
- **Primary** gets 100% of it (+500‰); **Secondary** gets 50% (+250‰).
- **Retooling** when changing focus: 180 days (Standard), output of affected jobs −300‰ during retooling.

| Focus | Boosted jobs / effects |
|---|---|
| Industrial | Worker, Engineer, Munitions; +10% build speed on local shipyards |
| Logistics | Dockworker; +4 extra freighter berths; stockpile cap +50% |
| Farming | Farmer; pop growth +20% |
| Economy | Clerk; trade income +25% |
| Research | Researcher |
| Mining | Miner, Refiner |
| Military | Soldier; army recruitment cost −25% |
| Fortress | Fort level +2 (see Sub-spec A22); garrison org +200 |

**Synergy bonus** (main spec 4.2 pairs, either order): +100‰ to both foci's jobs plus the named effect (e.g. Forge World: Workers consume 5 Ore instead of 6).

## B5. Stockpiles

- Planet stockpile cap: **500 per resource** base, +100 per Dockworker, +50% Logistics focus.
- Mining station local cap: 200; Logistics station: 1,000 (T1), 2,500 (T2), 5,000 (T3).
- **Overflow is lost**, with a UI warning at 90% full.
- Credits, Research, Influence have no cap.

---

## B6. Freighters

| Freighter | Capacity | Speed (lane units/day) | Build cost | Upkeep / month |
|---|---|---|---|---|
| Light | 100 | 6 | 40 Alloys | 1 Credit, 1 Fuel |
| Heavy | 400 | 4 | 120 Alloys, 10 Components | 3 Credits, 3 Fuel |
| Fast Courier (tech) | 50 | 10 | 60 Alloys, 10 Components | 2 Credits, 2 Fuel |

**Berths** (how many freighters a hub can operate):
- Logistics Station: 6 / 12 / 20 (T1/T2/T3)
- Logistics-focus planet: +4 berths
- Each Dockworker: +2 berths

Freighters without a berth sit idle.

## B7. Travel Times

- **In-system (impulse):** planet ↔ its orbit 1 day; planet ↔ planet 2–8 days by distance (Sol: Earth–Luna 1, Earth–Mars 3, Earth–Belt 4, Earth–Jupiter 8).
- **Hyperlane:** lengths 20–40 lane units. Light freighter ≈ 4–7 days per lane.
- **Warp** (if allowed on the route): distance / (speed × 600‰), plus 2 days charge.
- **Load / unload:** 1 day each.

**Throughput per freighter per month** = `capacity * 30 / round_trip_days`, with `round_trip = 2 × one_way + 2`.

| One-way trip | Light (100) | Heavy (400) |
|---|---|---|
| 1 day (orbit) | ~750 | ~3,000 |
| 4 days (in-system) | ~300 | ~850 |
| ~2 lanes (8–12 days) | ~165 | ~460 |
| ~3 lanes (15–22 days) | ~95 | ~260 |
| ~5 lanes (25–37 days) | ~55 | ~160 |

**Design consequence:** local supply chains are cheap, cross-cluster chains need many freighters. Forge Worlds next to shipyards are valuable, and deep strikes need forward depots.

## B8. Routes & Auto-Logistics

**Manual route:** `source → destination, resource, amount per trip, priority (Low 1 / Normal 2 / Critical 3), escort (optional)`.

**Demand targets (auto):** the player sets targets on consumers, e.g. "Luna Shipyard: keep Alloys ≥ 300". The network fills deficits.

**Assignment algorithm (deterministic, each day tick):**
1. Collect all open demands; `deficit = target − (stock + in-transit)`.
2. Sort demands by `(priority desc, deficit desc, consumer ID asc)`.
3. For each demand, find sources with surplus (`stock − own reserve`), sorted by travel time then source ID.
4. Assign idle freighters from hubs in range, sorted by distance to source then freighter ID; load `min(capacity, deficit, surplus)`.
5. Repeat until no idle freighters or no demands.

- **Reserve:** every stockpile keeps a player-set reserve (default 20% of cap) that auto-logistics won't take.
- **Hub range:** a hub's freighters serve routes up to 3 lanes away (T1), 5 (T2), 8 (T3).
- **Route safety:** each route can be *lane-only*, *warp-allowed*, or *avoid hostile systems* (longer path).

## B9. Convoy Raiding

- A hostile armed formation in a system where a freighter passes gets a **detection roll**: `sensor_strength * 1000 / (sensor_strength + 50)` ‰ per passage (listening posts add sensor strength to the owner's convoys' *warning*, allowing reroute).
- Detected, unescorted freighter: destroyed (cargo lost) or captured (Ohlan/pirates, cargo stolen).
- **Escorted convoy:** triggers a normal battle (Sub-spec A); freighters are non-combat targets with hull 200, evasion 100.
- **Patrol zones:** own warships on patrol in a system give convoys passing through a 60% chance to avoid detection.
- Losses are logged in the Logistics Manager with the route highlighted red.

---

## B10. Construction Costs

### Ships (Mk I, Standard pace)

| Hull | Alloys | Components | Other | Build days | Credits upkeep/mo |
|---|---|---|---|---|---|
| Corvette | 60 | 10 | — | 45 | 1 |
| Frigate | 90 | 15 | — | 60 | 1.5 |
| Destroyer | 140 | 30 | — | 75 | 2 |
| Cruiser | 260 | 60 | 10 RE | 120 | 4 |
| Battlecruiser | 420 | 100 | 20 RE | 180 | 6 |
| Battleship | 700 | 180 | 20 Exotics | 270 | 10 |
| Carrier | 550 | 150 | 10 Exotics | 240 | 8 |
| Troop Transport | 80 | 10 | — | 45 | 1 |
| Colony Ship | 150 | 20 | 50 Food + 1 pop | 90 | — |

- Modules add cost (weapons 10–60 alloys, 5–40 components each).
- Mk II: +30% cost, Mk III: +60%.
- **Materials are consumed as construction progresses** (daily share). If the shipyard stockpile runs dry, construction pauses; it doesn't fail.

**Shipyard size:** S (up to Destroyer), M (up to Battlecruiser/Carrier), L (all). One build at a time per dock; docks: 1 (T1), 2 (T2), 3 (T3).

### Stations

| Station | Alloys | Components | Build days |
|---|---|---|---|
| Outpost (system claim) | 80 | — | 60 |
| Mining Station | 100 | — | 60 |
| Logistics Station T1 | 150 | 20 | 90 |
| Shipyard S | 200 | 40 | 120 |
| Defensive Platform | 150 | 30 | 90 |
| Listening Post | 80 | 20 | 60 |
| Supply Depot | 150 | 20 | 90 |
| Interdictor | 250 | 80 | 150 |

Upgrades T2/T3: ×2 / ×4 the base cost.

### Planet buildings
Standard building: 80 Alloys, 90 days. Advanced (tech-unlocked): 150 Alloys + 30 Components, 150 days.

## B11. Mining Stations

| Location | Output / month |
|---|---|
| Asteroid belt | 15 Ore (or 4 RE if RE belt) |
| Moon / barren | 10 Ore |
| Gas giant | 8 Fuel (Refinery station) |
| Exotic anomaly | 2 Exotics |

Mining focus on the system's planet gives +250‰ to stations in the same system.

## B12. Fleet Supply

| Size | Fuel / month moving | Fuel / month idle |
|---|---|---|
| S (corvette, frigate) | 1 | 0 |
| M (destroyer, cruiser) | 2 | 0.5 |
| L (battlecruiser, carrier) | 4 | 1 |
| XL (battleship) | 6 | 1.5 |

- Warp: ×2 fuel. Jump: flat 20 fuel per L/XL ship per jump.
- **Ammo** refills from local depot/planet munitions: 1 Munitions per 2 ammo.
- **Supply range:** owned planet 1 lane; Supply Depot 2 / 3 / 4 lanes (T1/T2/T3); allied territory with military access 1 lane.
- A fleet in range draws from the **nearest depot/planet stockpile**, which must itself be supplied by convoys.
- **Out of supply:** see Sub-spec A13; after 30 days, 1% hull attrition per day.

## B13. Credits: Income & Upkeep

- **Income:** capital base 20, taxes (1/pop), Clerks (4), trade (B15), Trade Hub synergy (+2 credits per 100 cargo units passing through its hub).
- **Upkeep:** ships (B10), stations (1–6 per tier), buildings 1 each, armies 0.5 per company, freighters (B6).
- **Deficit:** stockpiled credits drain; at 0, stability −10 per month on all planets and new construction halts.

## B14. Research

- **Capital base:** 40 RP/month. Researchers 3 each. Research Station +15. Academy World synergy +100‰.
- **Parallel slots:** 2 (+1 at Tier 3 Society tech).

| Tier | Cost (RP) | Typical time with 2 slots |
|---|---|---|
| 1 | 250 | 4–6 months |
| 2 | 800 | 8–12 months |
| 3 | 2,200 | ~1–1.5 years |
| 4 | 5,500 | ~2 years |
| 5 | 12,000 | ~3 years |

(Pace multiplier applies.) Each tier needs 3 techs from the tier below in the same branch.

**Tech fragments (reverse engineering):** 100 fragments of a faction unlock one of that faction's techs at 50% RP cost; humans need 70.

## B15. Trade

- Trade Stations enable trade with factions within 3 lanes.
- **Trade deals:** resource-for-resource or for credits at base value ± AI valuation (scarcity: ×1.5 if the AI is short).
- **Traded goods must be physically delivered by convoy** (either side's freighters, as agreed in the deal).
- Passive trade income: each Trade Station yields `2 × (number of trading partners in range)` credits/month.

## B16. Influence

- **Income:** 3/month base, +1 per Council seat, +1 per 3 positive relationships, +2 Economy-focus capital.
- **Costs:** treaty proposal 10–50, claim system 25, edicts 20–100, protectorate 30.

## B17. Population Growth

- Each planet accumulates **growth points** monthly: `30 + 3 × free housing`, ×Farming bonuses.
- At 1,000 points → +1 pop (species chosen by weighted local mix).
- **Requires local food surplus.** Starvation (food at 0): no growth, stability −20, −1 pop every 3 months.
- Colonisation: colony ship brings 1 pop; new colonies get +100% growth for 5 years.

## B18. Stability (0–100, planet)

| Factor | Effect |
|---|---|
| Base | 50 |
| Food surplus | +5 |
| Starvation | −20 |
| Garrison present | +5 per company (max +15) |
| War weariness | −1 per 5% of empire losses this war (max −20) |
| Retooling | −5 |
| Occupation | −40, decays +2/month |
| Unemployed pops | −10 each |
| Species opinion | ±10 |
| Credits deficit | −10/month (stacks) |

- **< 30:** job output −25%. **< 15:** strikes (random building offline). **< 5:** revolt (rebel army spawns).

---

## B19. Sol Opening (Humans, Standard pace)

**Earth** (Large, Terran, capital, 24 pops): Primary Industrial, Secondary Research.
Jobs: 6 Farmers, 2 Miners, 6 Workers, 2 Engineers, 1 Munitions, 4 Researchers, 3 Clerks.

**Orbitals:** Luna Shipyard S (T1), Earth Logistics Station T1 with 3 Light Freighters, 3 belt Mining Stations, 1 Listening Post at Neptune.
**Uncolonised targets:** Mars (Medium, Desert), Venus (Toxic), Titan (Small, Arctic).
**Starting fleet:** 3 Corvettes, 1 Destroyer, 1 Scout, 1 Colony Ship.
**Starting stockpile (Earth):** 400 Alloys, 100 Components, 100 Rare Earths, 300 Food, 200 Ore, 200 Munitions, 200 Fuel, 500 Credits.

**Calculated monthly flow (Earth + belt):**

| Resource | Produced | Consumed | Net |
|---|---|---|---|
| Food | 36 | 24 | **+12** |
| Ore | 8 + 45 belt | 38 | **+15** |
| Alloys | 27 | 2 | **+25** |
| Components | 6 | — | **+6** |
| Munitions | 12 | — | **+12** |
| Research | 40 base + 15 | — | **55 RP** |
| Credits | 20 capital + 24 tax + 12 clerks | ~25 upkeep (10 buildings, 5 ships, 3 freighters, 7 stations) | **+31** |

**Belt → Earth ore haul:** 4-day trip, ~300/month per Light Freighter vs. 45 needed. One freighter covers it early; freighters only become the bottleneck with interstellar expansion (by design).

**What that buys (months of net alloy income):** Corvette ~2.4 · Destroyer ~5.6 · Cruiser ~10. The early game is a corvette/destroyer era; cruisers need a second industrial world (Mars) or a Forge World. Components are the other early constraint (Cruiser ~10 months).

## B20. Economy Balance Targets

- First colony founded: by month 6–12.
- First cruiser: by year 2–3 (Standard).
- Mid-game (year 15): ~6–10 colonies, 2–3 shipyards, 60–120 alloys/month, and freight that isn't a bottleneck:
  over the last year freighters average ≤ 80% busy, with at most 3 months above 95% (was "20–40 freighters";
  changed 2026-10-01, see change log).
- **Logistics should cap growth, not block it:** an empire with half the needed freighters should run at ~70% efficiency, not collapse.
- Food should never be a surprise: 3-month early warning before starvation.
- Harness: `tests/economy_harness.gd` runs AI empires for 50 in-game years across seeds; reports resource curves, freighter utilisation, time-to-milestones.

## B21. Open Tuning Items
1. Components may be too tight early; watch whether players are forced into Fabricators on Earth too soon.
2. Freighter upkeep vs. value: check that players don't skip auto-logistics by over-building freighters.
3. Trade Hub credits per cargo passing: risk of self-looping convoys for profit; exclude same-owner round trips.
4. Krothi food burden: needs its own pass once species hooks exist.
