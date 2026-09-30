# DEATHWORLDERS — Game Design Specification

*Working title. Version 1.2 — planning draft. Target engine: Godot 4.*

**Document set**
- Sub-spec A: Combat & Ground Formulas
- Sub-spec B: Economy & Logistics Numbers
- Sub-spec C: Data Schemas & Mod API
- Sub-spec D: Scale, Expansion & World Mechanics (sectors, governors, templates, alerts, war footing, reach, pirates, planet character traits, fog of war, salvage fields)
- Sub-spec E: Diplomacy, AI Personalities & Victory (opinion/trust, treaties, acceptance formula, war score, Council, Legend numbers, victory thresholds)
- Sub-spec F: UI & UX (HUD, map modes, wireframes for all key screens, input map, visual language)
- M1 Build Plan

---

## 1. Vision

A real-time-with-pause 4X space strategy game in the "Humanity, F*** Yeah" (HFY) tradition. The galaxy is old, polite, and fragile. Humanity arrives late, underestimated and underequipped, and wins through the things the galaxy considers primitive: stubbornness, improvisation, pack loyalty, a deathworld's durability, and a willingness to do the thing everyone else said was insane.

**Core fantasy:** "They thought we were the junior species. They were wrong."

**Design pillars**

1. **Logistics is strategy.** Resources are physical. They sit where they're made until something carries them. Supply lines win wars.
2. **Decide before the battle, not during it.** Combat auto-resolves. The player's skill lives in intelligence, loadouts, doctrine, and choosing when and where to fight.
3. **Earn the galaxy's respect.** Humanity's reputation evolves from "dangerous primitives" to "the ones you call when everything is on fire."
4. **Three zoom levels, one simulation.** Galaxy, Cluster, and Solar views are lenses on the same continuous world.

---

## 2. Game Loop & Time

**Time model:** Continuous game time, Stellaris-style. Pause plus speeds 1×, 2×, 4×, 8×.

| Tick | Frequency | Handles |
|---|---|---|
| Hour tick | Every in-game hour | Ship movement, convoy transit, combat rounds |
| Day tick | Daily | Production, construction progress, research points |
| Month tick | Monthly | Economy settlement, upkeep, diplomacy drift, events, pop growth |

**Macro loop:** Explore → Claim → Specialise planets → Build logistics network → Produce → Research → Diplomacy/War → Respond to galactic crises.

**Moment-to-moment loop:** Scan intel → adjust convoy routes → queue ships/stations → set fleet doctrine & loadout → send forces → read battle reports → react.

---

## 3. The Three Views

### 3.1 Galaxy View
- The whole galaxy as a set of **clusters** (regions of 5–15 star systems) joined by long-range jump corridors.
- Shows: faction borders, diplomatic relationships, fleet group movements between clusters, galactic events, intel coverage overlay.
- Actions: set strategic fleet destinations, diplomacy screen, galactic-scale logistics trunk routes.

### 3.2 Cluster View
- The star systems inside one cluster, connected by hyperlanes.
- Shows: system ownership, convoy routes and their traffic, fleet positions, supply range, listening post coverage.
- Actions: build and edit logistics routes, move fleets system-to-system, set patrol/escort zones, colonise.

### 3.3 Solar View
- One star system: star, planets, moons, asteroid belts, orbital stations.
- Shows: planet details, orbital slots, local stockpiles, docked/queued ships, ongoing battles.
- Actions: planet focus, build stations, shipyard queues, ship designer, invasion orders.

**Navigation:** Scroll-zoom transitions smoothly between views (galaxy → cluster → system). Double-click to dive in, right-click or Esc to back out.


### 3.4 Movement & FTL (layered)
All four movement modes exist, each with a clear role:

| Mode | Where | Who | Behaviour |
|---|---|---|---|
| **Impulse** | Inside a star system (Solar view) | Everyone | Free sublight movement between planets, stations, jump points. Takes days. |
| **Hyperlanes** | Between connected systems | Everyone (baseline) | Fast, predictable, creates chokepoints. Convoys default to lanes. |
| **Warp** | Any system within warp range | Species-start or mid-game tech | Slower than lanes, ignores lane network, needs charge-up at system edge. Bypasses chokepoints. |
| **Jump Drive** | Long-range point-to-point | Late-game tech, capital ships / fleets with jump tender | Near-instant, long cooldown, heavy fuel cost, exits disoriented (combat penalty for a few ticks). |

**Species starting FTL** (asymmetry): Humans start on hyperlanes and research warp fast (improvisers). Vess'kar start with warp. Krothi use hyperlanes only but get cheap lane-gate construction. Ohlan convoys get warp early. Thessari get stronger interdiction.

**Counterplay:**
- **Interdictor station:** gravity well that blocks warp/jump exits and pulls ships out of warp in range.
- **Lane gates / chokepoint fortresses** still matter for lane traffic.
- **Listening posts** detect warp signatures (charge-up is visible) and give early warning.

**Implications:** Galaxy/Cluster views show lane network plus warp range rings and jump cooldowns. Logistics routes can be set to lane-only or warp-allowed (faster but less protected). All movement positions are integer/fixed-point for determinism.

---

## 4. Planets

### 4.1 Planet Attributes
- **Type:** Terran, Ocean, Desert, Arctic, Toxic, Barren, Gas Giant (orbital only), Deathworld (rare, humans thrive).
- **Size:** determines building slots and population cap.
- **Habitability:** per species. Humans get a bonus on hostile worlds (deathworlder trait).
- **Deposits:** ore, rare earths, exotics, fertile land, energy potential.
- **Orbital slots:** 1–4, based on size. Hosts stations.

### 4.1b Sol (fixed human start)
Humans always start in a **handcrafted Sol system**; its position in the galaxy is randomised by the generator.
- Earth (capital, Terran, pre-built), Luna (orbital shipyard slot), Mars (early colony target), Venus (Toxic, late terraform), Mercury (mining), asteroid belt (mining stations), Jupiter/Saturn (gas giants, fuel + orbital slots), Uranus/Neptune (outer defence, listening posts).
- Hand-tuned deposits so the human opening is familiar every match and balanceable for MP.
- Other species start on generated homeworlds from a species template (not fixed layouts).

### 4.2 Dual Focus System
Every colonised planet picks a **Primary** and **Secondary** focus.

- Primary focus: 100% bonus, unlocks the focus's special buildings.
- Secondary focus: 50% bonus, no special buildings.
- Changing focus takes time (retooling period, 6–12 months) and drops output during the transition.

| Focus | Produces / Enables |
|---|---|
| Industrial | Alloys, components, faster construction |
| Logistics | Freighter capacity, depot storage, supply range |
| Farming | Food, pop growth |
| Economy | Credits, trade value, influence |
| Research | Research points |
| Mining | Raw ore, rare earths |
| Military | Army recruitment, garrison strength, fortress bonuses |
| Fortress | Planetary shields, ground defence, siege resistance |

**Synergy pairs** (bonus when combined as Primary + Secondary):

- Industrial + Mining → *Forge World* (+ alloy efficiency, no ore transport needed)
- Logistics + Economy → *Trade Hub* (+ credits per convoy passing through)
- Military + Fortress → *Bastion* (+ garrison morale, siege duration)
- Research + Economy → *Academy World* (+ research, + leader XP)
- Farming + Logistics → *Breadbasket* (+ food export capacity)

---

## 5. Orbital Stations

Stations occupy orbital slots in a system (around planets, belts, or the star).

| Station | Function |
|---|---|
| Shipyard | Builds ships. Size tier (S/M/L) limits hull classes. Needs alloys + components delivered. |
| Mining Station | Extracts from asteroids/moons/gas giants. Output stockpiles locally. |
| Logistics Station | Hosts freighters, stores goods, runs convoy routes. |
| Defensive Platform | Static weapons, shields. Participates in battles in-system. |
| Listening Post | Intel coverage: detects fleets, reveals composition at range. |
| Supply Depot | Refuels and resupplies fleets; extends supply range. |
| Research Station | Bonus research; studies anomalies and salvage. |
| Trade Station | Enables trade with other factions in range. |
| Interdictor | Blocks warp/jump arrivals in range; pulls passing warp traffic out. |
| Jump Beacon | Late game: extends jump range for allied fleets. |

Stations are upgradable (Tier I–III) and destructible. Capturing enemy stations is possible with boarding-capable forces.

---

## 6. Logistics (Core System)

### 6.1 Resource Types

**Physical (must be transported):**
- Food
- Ore
- Rare Earths
- Alloys (refined)
- Components (advanced manufacturing)
- Exotics (rare, late game)
- Munitions (fleet ammunition)
- Fuel

**Abstract (global pool):**
- Credits (financial systems are instant)
- Research Points (data travels at comms speed)
- Influence (diplomatic capital)

This split keeps the design readable: *money and knowledge are global, stuff is local.*

### 6.2 Stockpiles
- Every planet and logistics/mining station has a **local stockpile** with a capacity per resource.
- Production beyond capacity is wasted, which pushes players to build hauling capacity.

### 6.3 Freighters & Routes
- Freighters are **finite physical ships** owned by a Logistics Station or Logistics-focus planet.
- Each has cargo capacity, speed, and upkeep. They can be built, lost, and captured.
- **Routes** are defined as: Source → Destination, resource, quantity per trip, priority (Low/Normal/Critical).
- Freighters travel along hyperlanes in real time. Transit time matters.
- **Auto-logistics** option: the player sets demand targets ("keep Shipyard Alpha at 500 alloys") and the network assigns freighters by priority.

### 6.4 Consumers
- **Shipyards:** consume alloys, components per build.
- **Planets:** consume food per pop; construction consumes alloys.
- **Fleets:** consume fuel and munitions; draw from supply depots within supply range.
- **Armies:** consume food and munitions.

### 6.5 Supply & Attrition
- Fleets inside **supply range** (depots, owned planets, allied territory with access rights) resupply automatically.
- Out of supply: ammunition runs down (missile ships hit hardest), fuel drops, morale erodes, attrition damage begins.
- This makes deep strikes a real gamble and gives value to forward depots.

### 6.6 Convoy Warfare
- Convoys can be **raided** by enemy fleets and pirates.
- Counterplay: escort assignments, patrol zones, defensive platforms along routes, route rerouting.
- Raiding enemy logistics is a valid way to win a war without a decisive battle.

---

## 7. Military

### 7.1 Naval Hierarchy

| Formation | Size | Commander |
|---|---|---|
| Ship | 1 | Captain (optional) |
| Squadron | 2–6 ships | — |
| Task Force | 2–4 squadrons | Commodore |
| Fleet | 2–5 task forces | Admiral |
| Armada | 2+ fleets | Grand Admiral |

Formations are created automatically by unit count but can be manually organised. Each tier can hold a doctrine; lower tiers inherit unless overridden.

### 7.2 Ground Hierarchy

| Formation | Size | Commander |
|---|---|---|
| Squad | base unit | — |
| Company | 3–5 squads | — |
| Battalion | 3–5 companies | Major |
| Brigade | 2–4 battalions | Colonel |
| Army | 2+ brigades | General |

### 7.3 Ship Classes

| Class | Role |
|---|---|
| Corvette | Fast, cheap; raiding, escort, screening |
| Frigate | Point defence, anti-fighter, escort |
| Destroyer | Anti-corvette, torpedo boat |
| Cruiser | Line workhorse, flexible |
| Battlecruiser | Fast heavy hitter |
| Battleship | Line anchor, heavy armour |
| Carrier | Fighters/bombers, long-range strike |
| Troop Transport | Carries ground forces |
| Assault Ship | Boarding actions, station capture |
| Freighter | Logistics (non-combat) |
| Scout | Exploration, intel |

### 7.4 Ship Customisation
**Fixed slot layouts per hull.** Each hull class (per species) has a predefined set of slots: **Weapon (S/M/L)**, **Defence**, **Utility**, **Core**. Research unlocks **Mk II / Mk III** hulls with extra or larger slots. Each weapon slot maps to a named hardpoint on the 3D model, so swapping a railgun for a missile pod changes the visible turret.

Example: Human Cruiser Mk I, 2× Medium Weapon, 1× Small Weapon, 2× Defence, 1× Utility, 1× Core.

**Weapon families:**
- **Kinetic** (railguns, mass drivers, autocannons): strong vs shields-light targets, cheap munitions. Humanity's signature.
- **Missile / Torpedo**: long range, high burst, countered by point defence, ammo-hungry.
- **Energy** (lasers, plasma): strong vs armour, weak vs shields, energy-hungry.
- **Fighters / Bombers**: carrier-launched, countered by flak.
- **Boarding pods**: capture ships and stations.

**Defence:** armour (vs kinetic/energy), shields (vs energy/missiles), point defence (vs missiles/fighters), ECM (vs missile lock).

**Design library & sharing:**
- Saved designs persist in a personal library across matches.
- Export/import as a file and as a short copyable text code (JSON → compressed → base64).
- A design stores species, hull ID + Mk, and component string IDs, plus a format version.
- On import: missing tech shows the design as locked until researched; missing mod content is flagged with the required mod; wrong species hulls are rejected.
- In MP, adding a design to your empire is a Command, so it stays deterministic.

**Refit before battle:** Ships docked at a shipyard or supply depot can swap loadouts in hours/days rather than being rebuilt. This is where intelligence pays off.

### 7.5 Intelligence (drives loadout decisions)

Intel on an enemy force has levels:

| Level | You know |
|---|---|
| 0 — Unknown | Something is there |
| 1 — Contact | Approximate size |
| 2 — Classified | Ship classes and count |
| 3 — Profiled | Weapon families, defence type |
| 4 — Full | Exact loadouts, doctrine, commander traits |

Intel sources: listening posts, scouts, captured ships, allied intel sharing, spies (see Espionage), and battle experience against a faction (partial profile carried forward).

Enemies can also use deception (ECM, decoys, false signatures) to feed bad intel.

### 7.6 Doctrine (the player's "battle control")
Since battles auto-resolve, player control lives in pre-battle settings:

- **Engagement range:** Standoff / Line / Close / Boarding
- **Target priority:** Largest / Weakest / Carriers first / Escorts first / Missiles first
- **Retreat threshold:** Never, 25%, 50%, 75% losses
- **Formation:** Screen-forward, Wedge, Sphere (defensive), Dispersed (vs area weapons)
- **Stance:** Aggressive, Balanced, Defensive, Delaying action

### 7.7 Battle Resolution
Battles run in rounds (hour ticks) and phases by range:

1. **Long range:** missiles, torpedoes, fighter strikes, point defence responds.
2. **Medium range:** kinetics, energy weapons, main line exchange.
3. **Close range:** broadsides, boarding actions.

Engagement range doctrine and ship speed determine which phases a side can force or skip.

**Resolution factors:** hull/armour/shields, weapon vs defence matchups, ammunition remaining, commander traits, morale, veterancy, supply state, terrain (nebulae reduce range, asteroid fields help small ships, stations add firepower).

**Morale:** Ships and formations can break and retreat. Humans get the *Stubborn* trait: slower morale loss and "last stand" bonuses when outnumbered.

**Battle reports (report only, no replay):** since there's no battle visual, the report is the payoff and must be excellent:
- **Header:** location, date, sides, commanders, result (Decisive / Marginal / Pyrrhic victory/defeat, Retreat).
- **Phase timeline:** long / medium / close range rounds with a simple strength-over-time chart per side.
- **Losses & damage:** ships lost/damaged by class, casualties, salvage gained (tech fragments).
- **Matchup breakdown:** which weapon families did the work and what countered them ("Enemy point defence intercepted 68% of your missiles").
- **Key moments:** generated narrative lines ("ISS *Vanguard* rammed the enemy flagship"). HFY flavour lives here.
- **Lessons / intel gained:** enemy loadout revealed, intel level raised, suggested counter ("Consider kinetic refit").
- **Honours:** MVP ship, commander XP, veterancy gained.
- Reports archived per war; notable ones become "famous battles" referenced in later events.

### 7.8 Planetary Invasion
1. **Orbital superiority:** clear enemy fleets and defensive platforms.
2. **Bombardment (optional):** reduces garrison and fortifications, damages infrastructure and angers the population, with diplomatic penalties.
3. **Landing:** troop transports deliver armies. Contested landings take casualties; Aerospace and Marines reduce them.
4. **Ground battle:** auto-resolved with unit-type matchups (7.9).
5. **Occupation:** unrest, resistance, gradual integration.

### 7.9 Ground Units & Matchups
Battalions are built from companies of specific unit types. Composition matters as much as size.

| Unit type | Strong vs | Weak vs | Notes |
|---|---|---|---|
| Infantry | Garrison (urban), Engineers | Armour, Artillery | Cheap, holds ground, best in cities/jungle |
| Armour | Infantry, Artillery | Anti-Armour, rough terrain | Fast breakthrough; poor on Toxic/Ocean worlds |
| Anti-Armour | Armour | Infantry, Artillery | Defensive specialists |
| Artillery | Infantry, fortifications | Armour, Aerospace | Siege; reduces fortification level |
| Aerospace | Artillery, Armour | Anti-Air | Supports landings, recon (+intel) |
| Anti-Air | Aerospace | Infantry, Armour | Denies air support |
| Marines / Special Forces | Fortifications, HQs | Armour | Spearhead landings, sabotage, capture stations |
| Engineers | — | Everything | Build fortifications, clear defences, speed occupation |

**Ground battle rounds:** Landing → Breakthrough → Siege → Mop-up. Each round applies matchups, terrain, fortification, supply, morale.

**Terrain by planet type:** e.g. Ocean (limits Armour, boosts Marines), Desert (boosts Armour), Arctic (attrition to non-adapted species), Toxic (penalties unless adapted), Deathworld (big bonus to humans, heavy attrition to others).

**Species variants:** each species reskins and tweaks unit types (e.g. human Marines get Stubborn; Krothi Swarm Infantry are cheap and numerous; Vess'kar Aerospace is elite but costly; Thessari garrisons get fortification bonuses).

**Intel matters here too:** garrison composition is only known at Intel Level 2+, so recon before landing lets you bring the right mix.

**Doctrine for ground:** Assault (fast, costly), Methodical (slow, fewer losses), Siege (starve out, needs orbital blockade).

---

## 8. Research

### 8.1 Branches
- **Physics:** weapons, shields, sensors, FTL
- **Engineering:** hulls, stations, construction, mining
- **Logistics:** freighter tech, supply range, depot capacity, automation
- **Society:** pop growth, stability, diplomacy, alien relations
- **Military Doctrine:** unlocks formations, doctrine options, veterancy, boarding tactics
- **Xeno Studies:** alien tech integration, reverse engineering

### 8.2 Structure
- **Fixed tree** (decided): same tree every match, fully visible, so players can plan builds and learn optimal paths (good for competitive MP).
- Tiers, prerequisites, and a few mutually exclusive choices (e.g. *Kinetic Supremacy* vs *Energy Mastery* specialisations).
- Species-specific branches/nodes attached to the shared tree.
- Research points are global; research stations and academy worlds boost output.

### 8.3 Reverse Engineering (HFY signature)
- Salvage from battles and captured ships grants **Tech Fragments**.
- Enough fragments unlock alien technology, often **adapted in human style**: cruder, sturdier, more dangerous. Example: alien precision beam → human "overclocked" version with more damage and overheat risk.
- Alien factions react to humans using their tech (some flattered, some furious).

---

## 9. Diplomacy

### 9.1 Actors
- **Empires:** alien species with governments, traits, and agendas.
- **Conglomerates:** megacorporations with territory, fleets, and money; they trade, hire mercenaries, and lobby.
- **Minor species / protectorates:** weak civilisations that need protection.
- **Pirates / raiders:** non-diplomatic threats who can be bribed or crushed.
- **Galactic Council:** an assembly of senior species that passes resolutions (trade rules, weapon bans, sanctions, crisis mandates).

### 9.2 Relations
Opinion score (−100 to +100) driven by treaties, trade, shared enemies, border friction, reputation, and incidents.

**Treaties:** Non-aggression, Trade agreement, Research pact, Intel sharing, Military access, Defence pact, Alliance, Protectorate.

### 9.3 Guardian Contracts (HFY signature)
- Weaker species can request human protection.
- Player can accept: defend their systems, station fleets, fight their wars.
- Rewards: resources, tech, influence, their loyalty, and **Legend** (see 10).
- Failing a protectorate hurts reputation hard.

### 9.4 Joint Warfare
- Allied fleets can fight together; combined battles use both sides' doctrines.
- Humans can lead coalitions; allied commanders' trust grows with shared victories.

---

## 10. Playable Species & HFY Identity

All species are playable. **Fixed roster only** (decided): no custom species creator; each species is hand-balanced. Humanity remains the narrative centre of the HFY fantasy, but every species gets a distinct identity mechanic, so playing an alien is a different game, not a reskin. When you play an alien, the HFY events flip perspective: you experience the humans as the terrifying, baffling newcomers.

### 10.1 Starting Roster (working names)

| Species | Archetype | Signature mechanic | Military bias |
|---|---|---|---|
| **Humans (Terran Union)** | Late-arriving deathworlders | **Legend** (Respect/Fear meter), reverse-engineering bonus | Kinetics, boarding, durable hulls |
| **Vess'kar Ascendancy** | Ancient council elite | **Precedence**: bonus Council votes, can veto resolutions; stagnates if it never adapts | Energy weapons, shields; fragile hulls |
| **Krothi Brood** | Swarm / hive | **Brood Surge**: pop converts into cheap ships/armies fast; enormous food logistics burden | Mass corvettes, fighters, attrition |
| **Ohlan Consortium** | Merchant conglomerate | **Contracts**: hire mercenary fleets, own trade routes in others' territory, profit from convoys | Mercenaries, missiles, ECM |
| **Thessari Accord** | Peaceful, defensive | **Sanctuary**: strong planetary defences, attracts protectors; wins through alliances | Shields, fortresses, point defence |

The Galactic Crisis remains a non-playable threat.

### 10.2 Species Definition (data-driven)
Each species is a `SpeciesDef` resource: traits, habitability table, starting tech, ship/hull style, weapon affinities, AI personality weights, signature mechanic hook, event pack. Adding species later = new resource + mechanic script.

### 10.3 Human Traits
- **Deathworlder:** high durability, disease resistance, bonus on hostile worlds.
- **Stubborn:** slow morale loss, last-stand bonuses.
- **Pack Bonding:** units that fight together gain cohesion; humans bond with allies (allied opinion grows faster).
- **Improvisers:** cheaper refits, faster reverse engineering, field repairs.
- **Persistence Hunters:** pursuit bonuses; retreating enemies take more losses.

### 10.4 Legend Meter (Humans)
A galaxy-wide reputation score split into two axes:

- **Respect** (earned through honourable victories, defending the weak, keeping treaties)
- **Fear** (earned through overwhelming force, bombardment, broken treaties)

High Respect opens alliances and protectorate requests. High Fear makes enemies hesitate, surrender earlier, or pre-emptively gang up. Every species has a general reputation score; only humans get the full Legend mechanic.

### 10.5 Narrative Events
- **First contact** chains between every species pair, written from the player's perspective.
- **"They did WHAT?"** events: humans do something others consider insane (repairing a reactor mid-battle, befriending a predator species, ramming). Played as aliens, these arrive as intelligence reports and council panic.
- **Galactic Crisis:** see 10.6.

### 10.6 Galactic Crises (randomised)
One crisis is drawn at random per match (or chosen in settings; Epic games can roll a second). Each is telegraphed by early warning signs mid-game, and each stresses a different system so there's no single counter-strategy.

| Crisis | Nature | What it stresses |
|---|---|---|
| **The Devourers** | Extragalactic swarm that strips planets bare | Military mass, fortress worlds, coalition fleets |
| **The Silence** | Ancient machine intelligence wakes inside old Vess'kar tech | Research, espionage, tech choices (infected tech becomes a liability) |
| **The Rift** | Dimensional incursion; storms collapse hyperlanes | Logistics: routes break, supply networks must reroute |
| **The Blight** | Galactic plague hitting populations | Food, stability, farming; deathworlders resist it (HFY moment) |
| **The Returning** | Precursors come back to reclaim "their" galaxy | Diplomacy: they offer deals, split alliances, demand submission |

The species that contributes most to defeating the crisis earns Crisis Victory. In co-op, all players share it.

---

## 11. Leaders
- Admirals, generals, governors, scientists, envoys.
- Traits (e.g. *Aggressive*, *Logistician*, *Missile Specialist*, *Beloved by the Crew*), gain XP, can die in battle.
- Alien leaders can join humanity through alliances or defection.

---

## 12. Espionage (light layer)
- Agents placed in foreign empires: gather intel (raises intel levels), steal tech fragments, sabotage convoys, incite unrest.
- Counter-intelligence on your own worlds.
- Keep it light for MVP; it mainly feeds the intel system.

---

## 13. Population & Stability

### 13.1 Discrete Pops
- Each planet holds a number of **pop units**. Each pop has a **species**, a **job**, and **happiness**.
- **Jobs** come from buildings: Farmer, Miner, Worker (industry), Technician (energy), Researcher, Clerk (economy), Dockworker (logistics), Soldier (garrison/recruits), plus Unemployed.
- Planet focus boosts the jobs matching it (Primary 100%, Secondary 50%).
- Species traits modify job output (e.g. Krothi strong workers/soldiers, weak researchers; Vess'kar strong researchers).

### 13.2 Growth & Movement
- Pops grow over time if food is **locally** available (logistics!).
- Colonisation uses **colony ships** carrying pops from a source world.
- Migration between owned planets is slow and follows logistics routes; refugees flee wars.
- Multi-species planets possible via alliances, conquest, refugees; opinion between species affects stability.

### 13.3 Stability
- Planet stability from: food supply, security, war weariness, focus changes, occupation, species relations, amenities.
- Low stability reduces job output, then causes strikes, unrest, revolts.
- Army recruitment consumes Soldier pops, so wars cost population.

## 14. Victory & Loss

**Victory options** (each can be toggled in match settings):
- **Domination:** control X% of the galaxy.
- **Coalition:** lead an alliance holding a majority of the Galactic Council.
- **Legend:** reach maximum Respect and have Y protectorates.
- **Crisis Victory:** defeat the galactic crisis while leading the defence.

**Loss:** losing Earth (or all core worlds) or collapse of stability.

---

## 15. UI Outline
- **Top bar:** credits, research, influence, date, speed controls, alerts.
- **Left panel:** context (selected planet/fleet/station).
- **Right panel:** outliner (fleets, planets, convoys, research queue).
- **Bottom:** event log and battle report notifications.
- **Overlays:** logistics routes, supply range, intel coverage, diplomatic borders.
- **Key screens:** Ship Designer, Research Tree, Diplomacy, Logistics Manager, Battle Report.

---

## 16. Technical Approach

**Engine:** Godot 4.x, fresh build. Development driven through a Godot MCP (editor/scene control) and a headless Blender pipeline for 3D assets.

### 16.1 Language
- **GDScript** for UI, scenes, and glue: fastest iteration, best MCP/editor tooling support.
- **C#** is an option for the simulation core if tick performance becomes a bottleneck (familiar territory coming from Java). Decide at M3 based on profiling; start in GDScript.

### 16.2 Architecture
- **Simulation core is engine-light:** plain classes (`RefCounted`) holding game state and tick functions, with no dependency on scene nodes. Views read state and send commands; they never mutate state directly.
- **Autoloads (singletons):**
  - `GameClock`: time, speed, pause, emits hour/day/month tick signals
  - `GameState`: galaxy, factions, planets, fleets, convoys
  - `EventBus`: global signals (battle_resolved, convoy_lost, treaty_signed…)
  - `Database`: loads content definitions
- **Command pattern** for player and AI actions (e.g. `MoveFleetCommand`, `SetRouteCommand`). Same path for both, which simplifies AI, logging, and future replay.
- **Headless testing:** run the sim via `godot --headless` scripts (or GUT test framework) to batch-simulate battles and economies for balancing.

### 16.3 Scene Structure
```
Main.tscn
├── GalaxyView.tscn     (2D or 3D top-down, cluster nodes + corridors)
├── ClusterView.tscn    (systems + hyperlanes, convoy/fleet markers)
├── SolarView.tscn      (3D: star, planets, orbital stations, ships)
├── UI/
│   ├── TopBar.tscn
│   ├── ContextPanel.tscn
│   ├── Outliner.tscn
│   ├── ShipDesigner.tscn
│   ├── ResearchTree.tscn
│   ├── Diplomacy.tscn
│   ├── LogisticsManager.tscn
│   └── BattleReport.tscn
└── CameraRig.tscn      (zoom transitions between views)
```
Only the active view renders; the others stay unloaded or hidden while the sim keeps ticking.

### 16.4 Data-Driven Content
- Custom `Resource` types (`.tres`): `HullDef`, `ComponentDef`, `TechDef`, `SpeciesDef`, `StationDef`, `PlanetTypeDef`, `EventDef`.
- Adding a ship class or tech = new resource file, no code change.

### 16.5 Art Pipeline (Blender headless)
- Blender run headless with Python scripts to generate **procedural low-poly** assets: hull kits (bow/mid/stern modules + hardpoints), stations, planets, props.
- Export as **glTF 2.0 (.glb)** into `res://assets/models/`, with naming conventions Godot can auto-import.
- Ship visuals assembled modularly: hull + weapon mounts attached at named empties/markers, so the ship designer's loadout changes the model.
- Planets: sphere + shader (noise-based terrain/atmosphere) rather than unique models.
- **Art style (decided): clean low-poly across all three views.**
- Style target: clean, readable low-poly with strong faction silhouettes (humans: blocky, armoured, kinetic barrels; aliens: smooth, elegant, fragile-looking).

### 16.6 Other
- **Seeded RNG** (`RandomNumberGenerator` with stored seed) for reproducible galaxies and battles.
- **Save/load:** serialise `GameState` to JSON or binary via `FileAccess`; autosave on month ticks.
- **Performance targets:** ~200 systems, ~1,000 ships, ~300 active convoys at 8× speed. Use `MultiMeshInstance3D` for large fleets and convoy markers; resolve distant battles at lower fidelity.

### 16.7 Platform: PC first, Steam Deck/controller-ready
Release target is PC (mouse + keyboard), but everything is built so controller/Deck support can be added without a rewrite:
- **Input via InputMap actions only**; no hardcoded mouse buttons or keys in game logic. Actions like `select`, `context_action`, `zoom_in`, `view_up`, `open_outliner`.
- **Cursor-independent UI:** every UI control has focus neighbours set; all screens navigable by D-pad/stick focus.
- **No hover-only information:** tooltips also reachable by focus/hold.
- **Resolution:** minimum target 1280×800 (Deck); UI scales with a user setting; minimum text size readable at 7".
- **Camera:** zoom/pan designed for analog sticks as well as mouse.
- **Performance budget** mindful of Deck-class hardware (MultiMesh, LODs on low-poly models).

### 16.8 Audio (mix)
- **Original score:** main theme, campaign key moments, victory/defeat, crisis arrival.
- **AI-generated music:** ambient/background tracks per view and per species theme (check the generator's licence for commercial use before shipping).
- **Procedural ambience:** layered soundscapes per view (galaxy hum, cluster traffic, system/planet ambience) and dynamic intensity layers driven by game state (peace → tension → war).
- **Stingers:** short cues for events (first contact, battle report arrival, protectorate request, "They did WHAT?").
- **Audio buses:** Music, Ambience, SFX, UI, Voice; all moddable and replaceable.

### 16.9 Suggested Project Layout
```
res://
├── sim/          (state, tick logic, combat resolver, logistics, AI)
├── data/         (.tres content definitions)
├── views/        (galaxy, cluster, solar scenes)
├── ui/
├── assets/models/ (Blender .glb output)
├── assets/shaders/
├── tools/blender/ (headless generation scripts)
└── tests/
```

---

## 17a. Story Campaign

A narrative campaign alongside the sandbox, built from the same simulation plus a scenario layer.

### Structure
- A sequence of **scenarios**, each a handcrafted or seeded setup with objectives, scripted events, and victory/fail conditions.
- Progress carries forward selectively: veteran commanders, reputation, unlocked tech branches.
- **The first scenarios double as the tutorial:** each introduces one system (views & time → planets & focus → logistics → fleets & doctrine → intel & refits → diplomacy → ground invasion).

### Draft Arc (human perspective)
1. **Contact:** humanity's first contact; the galaxy thinks you're a curiosity.
2. **Underestimated:** a raid on Sol's outer colonies; learn logistics under pressure.
3. **The Council:** petition for recognition; diplomacy and trade.
4. **Guardians:** a weaker species asks for protection; first protectorate war.
5. **They Did What?:** a desperate, "impossible" human victory that changes the galaxy's view.
6. **The Coming Dark:** a crisis emerges; lead a coalition of species that once dismissed you.

### Perspective & co-op
- **Human perspective only.** Alien species are playable in sandbox and MP, not the campaign.
- **Solo or co-op.** Triggers run inside the deterministic sim, so the same lockstep model applies.

### Co-op: shared empire, split roles
Co-op players jointly run **one Terran Union**, each holding a role that owns certain command types:

| Players | Roles |
|---|---|
| 2 | **Admiral** (fleets, armies, doctrine, refits, invasions) · **Chancellor** (planets, logistics, industry, research, diplomacy) |
| 3 | Admiral · **Quartermaster** (logistics, industry, shipyards) · **Chancellor** (research, diplomacy, planets) |
| 4 | Admiral · **General** (ground forces, invasions) · Quartermaster · Chancellor |

- Role permissions are enforced per command type in the sim.
- **Request system:** roles send requests ("Need 6 cruisers at Sol by March", "Convoy escort needed on the Kepler route") that appear in the other player's outliner and can be accepted.
- Map pings and markers; shared intel and battle reports.
- Roles can be swapped or handed over mid-game; if a player drops, AI or the remaining player covers the role.
- The same shared-empire mode is available as an option in sandbox co-op (match setting).

### Tech
- `ScenarioDef` resources: map (seed or handcrafted), starting state, objectives, triggers → actions (spawn fleet, event popup, diplomacy change).
- Triggers run inside the deterministic sim, so scenarios also work in co-op.

---

## 17. Match Settings

All toggled at game setup (and saved with the match):

| Setting | Options |
|---|---|
| Galaxy size | Small (~60 systems), Medium (~120), Large (~200), Huge (~300) |
| Pace | Fast (~2–3 h), Standard (~5–6 h), Epic (10 h+). Scales research cost, build times, crisis timing |
| Players | 1–8 (human or AI slots) |
| Species | Any, duplicates allowed or not |
| AI difficulty | Per AI slot |
| Victory conditions | Enable/disable each; Domination % threshold |
| Crisis | Off / Early / Normal / Late |
| Starting position | Standard / Advanced start / Scattered |
| Fog of war | Off / Standard / Hardcore (Sub-spec D12) |

---

## 18. Multiplayer

Designed in from day one, even though the first playable build is single-player.

### 18.1 Modes
*(Shared-empire co-op with split roles: see 17a; also available in sandbox.)*

Competitive and co-op are equal priorities.

**Competitive** (FFA, teams)
- Species balance pass per milestone, using headless batch simulations.
- Observer slot for spectating.
- Anti-cheat stance: see 18.6 trade-off; server-side fog is a later upgrade if public ranked play happens.

**Co-op vs AI**
- Shared victory, shared vision (toggle), resource gifting via convoys (logistics still applies!), joint fleets under a coalition command.
- Shared Crisis Victory.
- AI difficulty scales with number of human players.

**Common**
- 2–8 players, any mix with AI slots.
- Drop-in AI takeover if a player disconnects; rejoin restores control.

### 18.2 Network Model: Deterministic Lockstep
Auto-resolved combat and a tick-based sim make lockstep a natural fit (the approach used by most grand strategy games).

- Every client runs the full simulation.
- Only **commands** travel over the network, never state.
- Commands are stamped for execution at `current_tick + delay` (e.g. +2 hour ticks) so all clients apply them at the same tick.
- Host relays commands and controls game speed.
- Low bandwidth, scales to thousands of ships.

### 18.3 Determinism Rules (apply to all sim code, even in single-player)
- **No floats in the sim.** Use integers / fixed-point for resources, positions on lanes, combat maths. Floats allowed in rendering only.
- **Stable iteration order:** iterate entities by sorted ID, never by hash order or scene tree order.
- **Seeded RNG streams** per subsystem (combat, events, AI, galaxy gen), advanced only inside the sim.
- **No sim reads from wall-clock time, frame delta, physics, or UI state.**
- **All state changes go through Commands** (already in the architecture).
- **AI decisions** run inside the sim tick, deterministically.

### 18.4 Desync Protection
- Clients hash `GameState` every month tick and compare.
- On mismatch: log the diverging subsystem (per-subsystem checksums), then resync from host snapshot.
- Debug build: headless determinism test runs the same seed + command log twice and diffs states.

### 18.5 Time Control in MP
- Host sets max speed; any player can request slowdown.
- Pause: limited pauses per player per hour of play, or unanimous-vote pause.
- Battles never pause the game (they're auto-resolved), keeping MP flowing.

### 18.6 Tech
- Godot high-level multiplayer (`ENetMultiplayerPeer`) for LAN/direct IP first; Steam networking later.
- Save/load works for MP: saves hold state + seed; clients joining a loaded game receive a snapshot.
- **Known trade-off:** lockstep means every client holds full state, so fog of war is client-enforced. Fine for friends; revisit for public competitive play.

---

## 18b. Modding (full support)

Designed in from M1, because the architecture choices are cheap now and impossible later.

### Mod types
- **Data mods:** new/changed species, hulls, components, techs, stations, planet types, events, crises, via `.tres`/JSON definitions.
- **Asset mods:** models (.glb), textures, shaders, audio, UI themes, portraits.
- **Script mods:** new mechanics via a documented **Mod API** (sim hooks), new AI personalities, UI panels.
- **Scenario mods:** custom maps, scenarios, and campaigns via `ScenarioDef`.

### Architecture rules (apply from M1)
- **Every content item has a stable string ID** (`human.hull.cruiser_mk1`), never referenced by array index or file path.
- **Layered Database:** base game → mods in load order. Mods can *add*, *override*, or *patch* (change specific fields) by ID.
- **Mod manifest** (`mod.json`): id, name, version, game version, dependencies, load-order hints, `affects_sim` flag.
- Mods packaged as Godot resource packs (`.pck`) or loose folders, loaded at startup via `ProjectSettings.load_resource_pack`.
- The base game is itself structured as the "core" mod, so the tools we use are the same ones modders use.

### Script mods & determinism
- Script mods only change the sim through the **Mod API**: hooks (`on_day_tick`, `on_battle_resolved`, `on_event_fired`…), command registration, and fixed-point maths helpers.
- Same determinism rules as core code (no floats in sim, seeded RNG streams provided by the API).
- **Security note:** GDScript mods can run arbitrary code. Show a clear warning for script mods; data/asset-only mods are flagged as safe.

### Multiplayer & mods
- Lobby compares a hash of all loaded `affects_sim` mods; mismatches block joining, with a list of what's missing.
- Cosmetic-only mods (UI themes, audio) are allowed to differ between clients.

### Modder tooling
- Documentation of all Def schemas and the Mod API.
- The Blender generation scripts and hardpoint naming conventions shipped as a modder kit, so custom ships plug into the fixed-slot designer.
- Steam Workshop integration later.

---

## 19. MVP Scope & Milestones

**M1 — Skeleton**
Deterministic sim core (fixed-point, command queue, seeded RNG), string-ID layered Database with base game as "core" mod, galaxy generation from match settings, three-view navigation, time controls, determinism test harness.

**M2 — Economy & Logistics**
Planet dual-focus, local stockpiles, freighters, routes, shipyard consumption.

**M3 — Military**
Ship classes, designer, fleets/squadrons, supply, auto-resolved battles with reports.

**M4 — AI, Diplomacy & Species**
Species definitions and signature mechanics, AI empires, treaties, opinion, war declarations.

**M4.5 — Multiplayer Prototype**
LAN lockstep, 2–4 players, command relay, desync checksums, host speed control.

**M5 — Research & Intel**
Research tree, listening posts, intel levels, refits.

**M6 — Ground War & Invasion**
Armies, transports, ground battles, occupation.

**M7 — HFY Layer**
Legend meter, guardian contracts, events, reverse engineering, galactic crisis.

**M8 — Campaign**
Scenario system, tutorial scenarios (1–2), then the full arc.

**M9 — Mod tooling**
Mod API documentation, script hooks, lobby mod hashing, modder kit (Blender scripts, schemas).

**M10 — Controller / Deck pass**
Focus navigation polish, controller glyphs, Deck performance tuning.

**Later:** espionage, Galactic Council, conglomerates, leaders.

---

## 20. Open Questions

**Resolved**
- Match length → toggle in match settings (section 17).
- Aliens → all playable, each with a signature mechanic (section 10).
- Multiplayer → designed in from the start, deterministic lockstep (section 18).

- Multiplayer focus → competitive and co-op equally (18.1).
- Ground combat → unit-type matchups (7.9).
- Galactic Crisis → several, randomised (10.6).

- Art style → clean low-poly everywhere (16.5).

- FTL → layered: impulse, hyperlanes, warp, jump drives (3.4).
- Population → discrete pop units (13).
- Ship designer → fixed slots per hull, Mk upgrades (7.4).
- Research → fixed tree (8.2).
- Battle visuals → detailed report only (7.7).
- Species → fixed roster (10).

- Human start → fixed, handcrafted Sol (4.1b).
- Modes → sandbox + story campaign (17a).
- Platforms → PC first, built controller/Deck-ready (16.7).

- Modding → full support: data, assets, scripts, scenarios (18b).
- Campaign → human perspective, solo + co-op (17a).

- Co-op campaign → shared empire, split roles (17a).
- Ship designs → library + export/import (7.4).
- Audio → mix of original, AI-generated, procedural (16.8).

**All top-level design questions resolved for v1.0.** Next: detailed sub-specs (numbers, formulas, schemas, wireframes, M1 task breakdown).
