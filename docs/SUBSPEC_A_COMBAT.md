# DEATHWORLDERS — Sub-spec A: Combat & Ground Formulas

*Version 0.1. Companion to the main Game Design Spec v1.0 (sections 7, 10, 18). All numbers are **starting values** for the balance harness, not final.*

**Change log**
- 2026-10-01 (M3 WP1): every number here is data: `combat_rules` (A0–A13) and `weapon_family` Defs (the A9
  matrix, plus which families point defence and ECM act on). Placeholders agreed with the owner: a Fighter
  Wing hangar component (fighter family, 40 dmg × 4, accuracy 800/750/700, ignores screening like torpedoes);
  crew by hull size S 20 / M 40 / L 80 / XL 120; Marine Barracks (utility) +60 marines, +30 crew; ammo 20 per
  ammo-using weapon; an Assault Ship (destroyer-sized: 700 hull, speed 7; 1S weapon, 1 defence, 2 utility);
  Thessari armour +30% and speed −1, Ohlan evasion +100 and hull −10% (A2 names only Vess'kar and Krothi);
  Defensive Platform and Pirate Base 1200 hull, 100 armour, 300 shield, immobile, 2M weapons (railguns),
  2 defence, 1 utility; Pirate Raider = corvette stats with 2 autocannons. Further placeholders, to confirm:
  veterancy XP thresholds Regular 100 / Veteran 300 / Elite 600 (A13 gives only the effects); tracking 0 for
  every A2 weapon (A2 has no tracking column); defence, utility and core slot sizes follow hull size (A2
  gives counts only): S hulls S, M hulls D_M / U_S / C_M, L and XL hulls D_L / U_M / C_L; carriers have two L
  hangars. Modules come in size S and fit any slot of their type.
- 2026-10-01 (M3 WP6, combat harness `tools/combat_harness.gd`, 300 seeded 6-vs-6 cruiser battles per
  matchup): A14's levers applied as data. Kinetic penetration +10 (autocannon 20, railgun 40, mass driver 70);
  armour ablation ×2 (divisor 10 → 5); kinetics punch shields (kinetic `shield_mult` 1000 → 1250); energy
  ignores more armour (`armor_eff` 500 → 300); point defence intercepts at 600‰ (was 450). Results (draws
  count half): mirror 50.5%; armour vs kinetic 81%; energy vs armour-heavy kinetic 72%; kinetic vs
  shield-heavy energy 75%; missiles at standoff 100% vs no PD, 85% vs 1 PD module per ship, 0% forced to
  Close; battles average 10 rounds. **Owner decision:** A14's "a hard counter holds to ~1.25× cost" conflicts
  with 70–85% at equal cost under A4–A10 (Lanchester; known issue 1): at 4 vs 5 the counter wins ~4%. It is
  report-only for M3 and revisited in M4 (species traits, morale).
- 2026-10-02 (M4 WP1, owner decisions): species traits apply as A13 modifiers of the ship owner's species
  (traits follow the crew: a captured ship fights with its captor's traits). Humans: kinetic damage +100‰,
  hull +100‰ (Deathworlder), Stubborn = morale loss x0.7 (`empire.morale_resist` 300 in the code's
  `1000 − resist` form), Last Stand (`combat_rules`: trigger morale 300 while outnumbered by
  `outnumbered_ratio`, +150‰ damage, morale floor 100 and no morale retreat roll for 6 rounds, once per
  battle), Persistence Hunters (+250‰ accuracy against disengaging ships, +1 pursuit round), Improvisers
  (salvage +50%). Other species' traits per the M4 plan (owner-approved placeholders). Species balance
  target (owner): each species' standard cruiser averages 40-60% against the others at exactly equal cost
  (interpolated between neighbouring ship counts), no pairing worse than 25/75. Met by scaling the M3 hull
  variations: humans hull x0.9 and cost x1.2 (A2's human values are now 1350 hull / 312 alloys for the
  cruiser), Vess'kar hull x1.3 and shield x1.6, Krothi cost x1.4, Thessari hull x1.15, and by giving the
  standard designs point defence (humans and Krothi swap the shield generator for it; Vess'kar and Thessari
  carry lasers with one railgun, a shield and point defence; Ohlan one missile pod and ECM). The A14 checks
  now run species-neutral (no trait modifiers); the combat harness adds the species matrix as a check.

---

## A0. Conventions (apply to all formulas)

- **Integers only in the sim.** Fractions are stored as **permille (‰)**: 1000 = 100%, 750 = 75%.
- **Multiplying by a permille value:** `x * p / 1000` using integer division (floor). Divide last to keep precision.
- **Random rolls:** `roll = rng.range(0, 1000)` from the **combat RNG stream** (seeded per battle from `match_seed ^ battle_id`). A check "succeeds" if `roll < chance`.
- **Damage variance:** `dmg * rng.range(850, 1151) / 1000` (±15%).
- **Clamp:** `clamp(v, lo, hi)`.
- **Modifier stacking:** all percentage bonuses from the same category are **summed** first, then applied once: `final = base * (1000 + sum_bonus) / 1000`. No compounding multipliers (keeps balance predictable and moddable).
- **Iteration order:** always by ascending entity ID.
- **Simultaneous resolution:** all attacks in a round are computed against **start-of-round state**; damage is collected and applied at the end of the round. No first-mover advantage.

---

# PART 1: SPACE COMBAT

## A1. Stat Blocks

### Ship
| Stat | Meaning |
|---|---|
| `hull` / `hull_max` | Structure points. 0 = destroyed |
| `armor` | Mitigation value; ablates under fire |
| `shield` / `shield_max` | Absorb pool, regenerates each round |
| `shield_regen` | ‰ of `shield_max` regained per round (default 50‰) |
| `evasion` | ‰ subtracted from enemy hit chance |
| `speed` | Used for range control, retreat, pursuit |
| `pd` | Point-defence intercept attempts per round (added to fleet pool) |
| `ammo` / `ammo_max` | Munitions for ammo-using weapons |
| `crew` | Boarding defence value |
| `morale` | 0–1000 (tracked at formation level, see A10) |
| `size` | S / M / L / XL (targeting weights, boarding) |
| `cost` | Used for battle scoring and salvage |

### Weapon
| Stat | Meaning |
|---|---|
| `family` | kinetic / energy / missile / fighter / boarding |
| `damage` | Per shot |
| `shots` | Per round |
| `accuracy[L, M, C]` | Base hit ‰ at Long / Medium / Close range |
| `penetration` | Flat armour ignored |
| `ammo_per_shot` | 0 for non-ammo weapons |
| `tracking` | ‰ bonus vs evasion (small weapons high, large low) |

## A2. Baseline Values (Tier 1, human)

### Weapons
| Weapon | Slot | Family | Dmg | Shots | Acc L / M / C | Pen | Ammo |
|---|---|---|---|---|---|---|---|
| Autocannon | S | kinetic | 30 | 3 | 100 / 650 / 800 | 10 | 0 |
| Railgun | M | kinetic | 100 | 1 | 400 / 750 / 800 | 30 | 0 |
| Pulse Laser | S | energy | 30 | 3 | 200 / 750 / 850 | 0 | 0 |
| Heavy Laser | M | energy | 100 | 1 | 350 / 800 / 850 | 0 | 0 |
| Missile Pod | M | missile | 95 | 2 | 900 / 700 / 150 | 0 | 1 |
| Torpedo | L | missile | 400 | 1 | 850 / 600 / 100 | 50 | 1 |
| Mass Driver | L | kinetic | 300 | 1 | 550 / 750 / 700 | 60 | 0 |

### Defence modules
| Module | Effect |
|---|---|
| Armour Plating | +80 armour |
| Shield Generator | +250 shield_max |
| Point Defence | +4 PD attempts/round |
| ECM Suite | −150‰ enemy missile accuracy vs this ship |
| Marine Barracks | +crew, enables boarding defence and attack |

### Hulls (Mk I, before modules)
| Hull | Hull pts | Armour | Shield | Evasion | Speed | Slots | Cost |
|---|---|---|---|---|---|---|---|
| Corvette | 300 | 20 | 60 | 300 | 8 | 2S · 1D | 100 |
| Frigate | 500 | 30 | 100 | 200 | 7 | 1S · 2D (PD bias) · 1U | 150 |
| Destroyer | 700 | 40 | 150 | 150 | 7 | 2S 1M · 1D · 1U | 220 |
| Cruiser | 1500 | 60 | 200 | 80 | 5 | 1S 2M · 2D · 1U · 1C | 400 |
| Battlecruiser | 2200 | 80 | 350 | 60 | 6 | 1S 2M 1L · 2D · 1U · 1C | 700 |
| Battleship | 4000 | 150 | 800 | 20 | 4 | 2S 2M 1L · 3D · 1U · 1C | 1200 |
| Carrier | 2500 | 80 | 500 | 30 | 4 | 2 Hangar · 2D · 1U · 1C | 1000 |

(S/M/L weapon, D defence, U utility, C core.) Species hulls vary these (e.g. Vess'kar: shield +40%, hull −25%; Krothi: cost −35%, hull −20%).

---

## A3. Battle Trigger & Setup

1. **Trigger:** hostile formations share a system at impulse range, or one side attacks. Checked on hour tick.
2. **Participants:** all fleets present, defensive platforms, armed stations, planetary shields (block bombardment only).
3. **Intel / ambush check:** if side X has intel ≥ 3 on side Y **and** Y has intel ≤ 1 on X, X gets a **free opening round** (Y does not fire in round 1).
4. **Starting range:** Long. Nebula: Medium. Ambush: attacker's preferred range.
5. **Formation morale** starts at 1000 minus penalties (out of supply −200, recent defeat −100).
6. **PD pool, targeting lists, and RNG** initialised.

## A4. Round Loop (1 round = 1 hour tick)

```
for each round:
  1. Range step (every 3rd round)          → A5
  2. Build PD pools per side               → A8
  3. Each ship: each weapon: pick target   → A6
     roll hits, interceptions, damage      → A7–A9
     (queue damage; no application yet)
  4. Apply all queued damage (sorted by target ID)
  5. Remove destroyed ships, record events
  6. Shield regen: shield += shield_max * regen / 1000
  7. Boarding actions (Close range only)   → A11
  8. Morale update                         → A10
  9. Retreat checks & disengage            → A10
 10. End check                             → A12
Hard cap: 48 rounds, then both sides disengage.
```

## A5. Range Control

- Bands: **Long (0) → Medium (1) → Close (2)**. Each side has a preferred band from doctrine (Standoff = Long, Line = Medium, Close/Boarding = Close).
- Every 3rd round, if preferences differ, one side moves the band one step toward its preference:
  `p_side_A = speed_A * 1000 / (speed_A + speed_B)` using each side's **slowest ship** speed. Roll decides who controls.
- If preferences match, band moves toward the shared preference.
- Terrain: nebula caps range at Medium; asteroid field +100‰ to the smaller-fleet side's control roll.

## A6. Targeting

1. Build a candidate list of alive enemies, filtered/ordered by doctrine target priority (Largest, Weakest, Carriers, Escorts, Missile ships).
2. **Screening:** while enemy escorts (Corvette/Frigate/Destroyer) are ≥ 30% of enemy hull count, capital ships can only be targeted with a weight of 50% (escorts screen).
3. Pick a target uniformly from the **top 3** of the ordered list (spreads fire, avoids perfect focus-fire).
4. Fighters and Torpedoes may ignore screening.

## A7. Hit Chance

```
hit = accuracy[band] + tracking + accuracy_bonuses − target.evasion
hit = clamp(hit, 50, 950)
```
- Missiles vs ECM: `accuracy − 150` per ECM suite.
- Veterancy and commander bonuses add to `accuracy_bonuses` (A13).

## A8. Point Defence (missiles & fighters)

- Each side has a **fleet-wide PD pool** each round = sum of `pd` of all its ships (+ platforms).
- Each incoming missile/fighter strike first consumes one PD attempt (if any left): intercept on `roll < 450`.
- Intercepted shots deal no damage. Missiles that survive then roll to hit normally.
- Once the pool is empty, remaining missiles get through untouched. Saturation beats PD.

## A9. Damage Pipeline

**Family matrix**

| Family | Vs shields (shield mult) | Armour effectiveness |
|---|---|---|
| Kinetic | 1000‰ | 1000‰ |
| Energy | 700‰ | 500‰ |
| Missile | 1000‰ | 750‰ |
| Fighter | 1000‰ | 750‰ |

Design intent: **armour counters kinetics, shields counter energy, PD counters missiles; energy bypasses armour, kinetics punch shields, missiles saturate.**

**Step 1: Shields**
```
shield_dmg = dmg * shield_mult / 1000
absorbed   = min(target.shield, shield_dmg)
target.shield -= absorbed
dmg = dmg − absorbed * 1000 / shield_mult     # leftover raw damage
```

**Step 2: Armour mitigation (diminishing returns, K = 100)**
```
eff_armor = max(0, target.armor * armor_eff / 1000 − penetration)
hull_dmg  = dmg * 100 / (100 + eff_armor)
```
(100 armour ≈ 50% reduction; 300 ≈ 75%.)

**Step 3: Ablation**
```
target.armor = max(0, target.armor − (dmg − hull_dmg) / 10)
```
Sustained fire wears armour down, rewarding long engagements and focus.

**Step 4: Hull**
`target.hull −= hull_dmg`. At ≤ 0 the ship is destroyed. At < 25% hull it is **crippled**: −200‰ accuracy, may be boarded, can't pursue.

## A10. Morale, Retreat & Pursuit

Morale is tracked per **Task Force** (and rolled up to Fleet).

**Morale loss per round**
```
loss = (hull lost this round by formation * 1000 / formation hull_max_at_start) * 2
     + 50  if a capital ship was destroyed
     + 150 if the commander's flagship was destroyed
     + 30  if outnumbered ≥ 2:1 (by cost)
loss = loss * morale_resist / 1000   # species/trait modifier
```
Humans (Stubborn): `morale_resist = 700`.

**Last Stand (Humans):** when outnumbered ≥ 2:1 by cost and morale < 300, +150‰ damage and morale can't drop below 100 for 6 rounds (once per battle).

**Retreat triggers:**
- losses ≥ doctrine retreat threshold (25/50/75%, or Never), **or**
- morale ≤ 200 → retreat roll each round: retreat if `roll < 1000 − morale*4`.

**Disengage:** retreating ships need **2 rounds** of FTL charge (warp/jump) or reach the system edge (lanes). During disengage they don't fire and **take +200‰ incoming accuracy**.

**Pursuit:** if the pursuer's speed ≥ the retreater's, the pursuer gets 1 extra round of fire. Humans (Persistence Hunters): +250‰ accuracy vs retreating ships, +1 pursuit round.

## A11. Boarding

- Only at **Close** range; only by ships with Assault/Marine modules; targets must be **crippled** or stations.
- Per attempt: `attack = marines * (1000 + bonuses)/1000`, `defence = target.crew`.
- Success chance: `clamp(attack * 1000 / (attack + defence), 50, 900)`.
- Success = ship **captured** (changes side next round; counts as salvage × 3). Failure = attacker loses 30% of committed marines.
- Humans: +200‰ boarding attack.

## A12. End of Battle

Ends when one side has no ships left in the battle, all of one side have disengaged, both prefer to disengage, or 48 rounds pass.

**Result classification** (by cost-weighted losses):

| Result | Condition |
|---|---|
| Decisive Victory | enemy lost ≥ 75%, you lost ≤ 25% |
| Victory | enemy lost more % than you, and ≥ 40% |
| Pyrrhic Victory | you hold the field but lost ≥ 60% |
| Marginal / Draw | loss % within 10 points of each other |
| Defeat / Rout | mirrors of the above |

**Salvage:** victor gains **tech fragments** toward the loser's faction = `sum(destroyed enemy cost) * 10 / 1000` (1%), ×3 for captured ships. Humans: +50% (Improvisers).

**Veterancy XP:** each surviving ship gains `rounds_fought * 10 + kills * 50`.

## A13. Modifier Sources (summed per A0)

| Source | Typical effect |
|---|---|
| Veterancy | Green 0 · Regular +50‰ acc · Veteran +100‰ acc, +50‰ morale resist · Elite +150‰ acc, +100‰ morale resist |
| Commander traits | e.g. *Missile Specialist* +100‰ missile acc; *Aggressive* +100‰ dmg, −100‰ evasion |
| Species traits | Humans: kinetic dmg +100‰, hull +100‰, Stubborn, Last Stand, Pursuit |
| Supply | Out of supply: −150‰ acc, no ammo refill, −200 starting morale |
| Terrain | Asteroid field: S/M hulls +100‰ evasion · Near star: shield regen −50% · Nebula: no Long band |
| Stations | Defensive platforms fight; system owner gets +50‰ acc (sensor net) |

## A14. Prototype Results & Balance Targets

A Python integer prototype of A5–A9 (6 cruisers per side, 200–500 seeded runs each) produced:

| Scenario | Result |
|---|---|
| Mirror (same design) | ~46–51% win (fair) |
| Right defence vs same weapons (armour vs kinetic) | ~100%: intel payoff is strong |
| Energy vs armour-heavy kinetic fleet | ~74% |
| Kinetic vs shield-heavy energy fleet | ~74–89% |
| Missiles at standoff vs no PD | ~87% |
| Missiles at standoff vs 1 PD per ship | ~45–66% (depends on PD intercept ‰) |
| Missiles forced to close range | ~1% |
| Counter fleet 6 vs countered fleet 7 | **0%**: numbers dominate |

Battles averaged **19–27 rounds** (about one in-game day).

**Balance targets for the harness**
- Mirror: 45–55%.
- Hard counter at equal cost: 70–85% win.
- A hard counter should hold against **up to ~1.25× cost** of the countered fleet.
- Battle length: 8–20 rounds typical.
- Missiles: dominant at standoff without PD, even at 1 PD/ship, weak at close.

**Known issues to fix first**
1. **Numbers overpower counters** (Lanchester effect; low variance from many shots). Planned levers: morale-driven retreat (A10, not in the prototype), stronger counter multipliers, screening (A6).
2. **Defence-only counters too absolute** (armour vs kinetic ~100%). Consider armour ablation ×1.5 or kinetic pen +10.
3. Battles run a little long; raise weapon damage ~20% or lower regen.

---

# PART 2: GROUND COMBAT

## A15. Unit Stat Block (per company)

| Stat | Meaning |
|---|---|
| `strength` | Manpower/equipment, 0–1000. 0 = destroyed |
| `org` / `org_max` | Cohesion, 0–1000 scale. 0 = routs to reserve |
| `attack` | Base damage output |
| `defense` | Mitigation (K = 50) |
| `width` | Frontage used (0 = support, fights from reserve) |
| `type` | One of 8 types (A16) |
| `cost`, `upkeep` | Alloys/munitions/food |

## A16. Unit Baselines (human, Tier 1)

| Type | Attack | Defense | Org | Width | Cost | Special |
|---|---|---|---|---|---|---|
| Infantry | 20 | 30 | 600 | 1 | 50 | +250‰ in Urban |
| Armour | 40 | 25 | 400 | 2 | 120 | Breakthrough: +200‰ attack in Breakthrough phase |
| Anti-Armour | 30 | 30 | 450 | 1 | 80 | — |
| Artillery | 35 | 10 | 350 | 1 | 90 | Fires from reserve; reduces fortification |
| Aerospace | 35 | 15 | 400 | 0 | 130 | Support; +1 intel level on garrison; reduces landing losses |
| Anti-Air | 20 | 20 | 400 | 1 | 70 | Shoots Aerospace in reserve |
| Marines | 30 | 30 | 700 | 1 | 110 | No landing penalty; ignore 50% of fortification |
| Engineers | 5 | 20 | 400 | 1 | 60 | Build +1 fort level / 30 days; clear −1 enemy fort / 10 days |

## A17. Matchup Matrix (attacker row → defender column, ‰)

| ↓ attacks → | Inf | Arm | AT | Art | Aero | AA | Mar | Eng |
|---|---|---|---|---|---|---|---|---|
| **Infantry** | 1000 | 600 | 1500 | 1000 | 600 | 1500 | 1000 | 1500 |
| **Armour** | 1500 | 1000 | 750 | 1500 | 600 | 1500 | 1500 | 1500 |
| **Anti-Armour** | 750 | 1500 | 1000 | 1000 | 600 | 1000 | 1000 | 1500 |
| **Artillery** | 1500 | 750 | 1500 | 1000 | 600 | 1000 | 1000 | 1500 |
| **Aerospace** | 1000 | 1500 | 1000 | 1500 | 1000 | 600 | 1000 | 1500 |
| **Anti-Air** | 750 | 600 | 1000 | 1000 | 1500 | 1000 | 1000 | 1000 |
| **Marines** | 1250 | 600 | 1000 | 1250 | 600 | 1250 | 1000 | 1500 |
| **Engineers** | 600 | 600 | 600 | 600 | 600 | 600 | 600 | 1000 |

Stored as data (`GroundMatchupDef`) so mods can add unit types.

## A18. Terrain (planet type → attack modifier ‰, plus attrition)

| Planet | Modifiers | Attrition (non-adapted species) |
|---|---|---|
| Terran | none | 0 |
| Ocean | Armour −500, Marines +250, Aerospace +100 | 0 |
| Desert | Armour +250, Infantry −100 | 1%/day |
| Arctic | Armour −100, all org_max −100 | 2%/day |
| Toxic | Aerospace −200 | 2%/day |
| Barren | Artillery +100, Infantry −100 | 1%/day |
| Deathworld | Armour −250 | 3%/day; **Humans: +250 attack & defense, no attrition** |
| Urban (developed planet overlay) | Infantry +250, Armour −250 | — |

Attrition = `strength −= strength * rate / 1000` per day. "Adapted" = habitability ≥ 60% for that species.

## A19. Frontage

- Planet frontage: **Small 6 · Medium 10 · Large 14** width.
- Each side fills frontage by priority (doctrine), the rest wait in **reserve**.
- Support units (width 0) and Artillery fight from reserve.
- Routed companies (org 0) move to reserve and reserves rotate in.

## A20. Ground Round Loop (1 round = 1 day tick)

```
Phases: Landing (day 1) → Breakthrough (days 2–5) → Siege (until fort = 0 or blockade breaks) → Mop-up
each day:
  1. Fill frontage from reserves
  2. Each attacking company picks a target on the enemy front
     (weighted toward its best matchup; Aerospace/AA may target reserve)
  3. Compute damage (A21), queue
  4. Apply damage simultaneously; update strength & org
  5. Rout companies at org 0; destroy at strength 0
  6. Fortification changes (A22), attrition (A18), resupply
  7. End check
```

## A21. Damage Formula

```
base  = attacker.attack * attacker.strength / 1000
mod   = matchup[att][def] * (1000 + terrain + species + doctrine + veterancy) / 1000
dmg   = base * mod / 1000 * roll(850..1150) / 1000
dmg   = dmg * (1000 − fort_reduction) / 1000          # defender only
str_loss = dmg * 50 / (50 + target.defense) * 10      # to strength (scale ×10; Infantry vs Infantry ≈ 125/day, ~8 days to destroy)
org_loss = str_loss * 3 / 2                           # cohesion breaks first: Infantry routs in ~3–4 days
```
Doctrine: **Assault** attacker +200 dmg, +300 own org loss · **Methodical** −150 dmg, −300 own losses · **Siege** no attack; relies on A22.

## A22. Fortification & Siege

- Fort level 0–5 (Fortress-focus planets start at 3; Bastion at 4).
- `fort_reduction = level * 80‰` (max 400‰ at level 5). Marines count it at half.
- Artillery: each day, roll vs `min(500, sum(artillery attack * strength / 1000) * 5)` ‰; on success fort −1.
- Orbital bombardment: −1 fort level per 5 days of bombardment (diplomatic + stability penalties).
- **Siege doctrine** (requires orbital blockade): defender gets no resupply; −3% strength and −50 org per day across the garrison.

## A23. Landing

1. Requires **orbital superiority** (no enemy warships or platforms in orbit).
2. Landing fire on day 1: the defender's AA, Artillery and front-line Infantry each deal normal A21 damage × 500‰ extra, split across landing companies. Reduced by 30% per attacking Aerospace company (max 60%) and by 50% if Marines lead the landing.
3. Non-Marine companies suffer **−250‰ attack** for the first 2 days.
4. Failed landing (all landed companies routed day 1) → survivors re-embark if transports remain.

## A24. End & Occupation

- Battle ends when one side has no companies with org > 0 and strength > 0, or the attacker withdraws.
- **Winner (attacker)** occupies the planet: stability −400, unrest rises by `pop * (1000 − opinion_of_occupier) / 1000`. Garrison of ≥ 2 companies suppresses revolt.
- Pops of the defending species may become refugees (see main spec 13.2).
- Captured fortifications drop 2 levels.

## A25. Ground Balance Targets

- Equal-cost mixed armies on Terran: 45–55%.
- Correct matchup composition vs a single-type army: 70–80%.
- Fort 5 garrison should need ~2× the attacker cost without siege, ~1.3× with a 30-day siege.
- Typical invasion length: 5–20 days; long sieges up to 90 days on Epic.

---

## A26. Harness Plan (Godot headless)

- `tests/combat_harness.gd`: loads Defs, runs N seeded battles per matchup table, outputs CSV (win %, rounds, losses by family).
- Same for ground (`ground_harness.gd`).
- Each run records `(match_seed, battle_id, param_hash)` so any anomaly can be replayed exactly.
- CI-style check: fail if any balance target in A14/A25 drifts outside its band.
