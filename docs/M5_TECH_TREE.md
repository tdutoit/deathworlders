# M5 Tech Tree: proposal (WP1)

*Approved by the owner 2026-10-04 (M5 WP1); data in data/core/defs/tech. 101 techs: 6 branches x 16, plus
5 species nodes. Costs follow B14 (tier 1 250, 2 800, 3 2,200, 4 5,500, 5 12,000 RP, times the pace).
Effect numbers are placeholders for WP14 balance.*

**Rules**
- Tier rule (B14): a tech of tier N needs 3 researched techs of tier N-1 in the same branch. Each branch has
  3 / 4 / 4 / 3 / 2 techs per tier, so an exclusive pick never blocks the next tier.
- Some techs also list a direct prerequisite (in brackets).
- Exclusive pairs: researching one locks the other for the rest of the match.
- Everything M4 uses (Mk I hulls, today's 13 components, 12 buildings and 16 stations) stays free, with no
  tech needed. Research unlocks new content and gives bonuses only, so M4 balance isn't disturbed. Starting
  techs: none (B14 gives no starting list). Species flavour comes from the species nodes.
- "Mk II" components are new data in WP3: the same family, about +25% to their main stat, +30% cost.
  "Mk III" components are about +50% to their main stat, +70% cost.
- `species_only` nodes appear only for that species and count toward the tier rule like any other tech.

## Physics: weapons, shields, sensors
| Tier | Tech | Effect / unlocks |
|---|---|---|
| 1 | Kinetic Theory | kinetic damage +5% |
| 1 | Coherent Optics | energy damage +5% |
| 1 | Deflector Theory | shield +10% |
| 2 | Magnetic Accelerators | unlocks Railgun Mk II, Autocannon Mk II |
| 2 | Focused Lasers | unlocks Pulse Laser Mk II, Heavy Laser Mk II |
| 2 | Shield Harmonics | unlocks Shield Generator Mk II |
| 2 | Passive Sensors | Listening Post T2 (3 lanes); sensor strength +10 |
| 3 | **Kinetic Supremacy** (excl. Energy Mastery) | kinetic damage +15%, penetration +10 |
| 3 | **Energy Mastery** (excl. Kinetic Supremacy) | energy damage +15%, shield regeneration +10% |
| 3 | Heavy Accelerators | unlocks Mass Driver Mk II |
| 3 | Deep Space Sensors | unlocks the Deep Space Array building (+3 lanes) |
| 4 | Plasma Containment | unlocks Plasma Lance (energy L) |
| 4 | Hypervelocity Rounds | unlocks Railgun Mk III, Mass Driver Mk III |
| 4 | Phased Shields | unlocks Shield Generator Mk III |
| 5 | Quantum Sensors | Listening Post T3 (4 lanes); sensor strength +20 |
| 5 | Singularity Weapons | unlocks Heavy Laser Mk III, Plasma Lance Mk II |

## Engineering: hulls, stations, construction, mining
| Tier | Tech | Effect / unlocks |
|---|---|---|
| 1 | Modular Construction | building build time -10% |
| 1 | Improved Mining | Miner output +10% |
| 1 | Hull Bracing | ship hull +5% |
| 2 | **Light Hulls Mk II** | corvette, frigate, destroyer Mk II hulls |
| 2 | Advanced Foundries | unlocks advanced buildings (Foundry II, Fabricator II) |
| 2 | Composite Armour | unlocks Armour Plate Mk II |
| 2 | Orbital Assembly | shipyard build speed +10% |
| 3 | **Capital Hulls Mk II** | cruiser, battlecruiser, battleship Mk II hulls |
| 3 | Zero-G Fabrication | Engineer output +15% |
| 3 | Deep Core Mining | +1 extraction building per rich deposit |
| 3 | Station Engineering | station build time -15%; +1 orbital slot on large and huge planets |
| 4 | **Light Hulls Mk III** | corvette, frigate, destroyer Mk III hulls |
| 4 | Reactive Armour | unlocks Armour Plate Mk III |
| 4 | Megastructure Theory | +1 building slot on every colony |
| 5 | **Capital Hulls Mk III** | cruiser, battlecruiser, battleship Mk III hulls |
| 5 | Exotic Matter Forging | Exotics use in ship costs -25% |

## Logistics: freighters, supply, depots, automation
| Tier | Tech | Effect / unlocks |
|---|---|---|
| 1 | Cargo Standardisation | freighter capacity +10% |
| 1 | Fuel Efficiency | ship fuel upkeep -10% |
| 1 | Route Planning | freighter speed +10% |
| 2 | Bulk Haulers | Heavy Freighter capacity +20% |
| 2 | Forward Depots | depot capacity +25% |
| 2 | Supply Doctrine | fleet supply range +1 lane |
| 2 | Stockpile Management | planet stockpile cap +25% |
| 3 | Fast Couriers | unlocks the Fast Courier hull (B6) |
| 3 | Automated Loading | Dockworker output +20%; freighter berths +1 |
| 3 | Logistics Networks | +1 sector cap (D3: 1 per 2 Logistics techs) |
| 3 | Convoy Escorts | freighter evasion +15% |
| 4 | Salvage Operations | unlocks the Salvage Bay component and the Salvage Tug hull (D13) |
| 4 | Strategic Reserves | Munitions and Fuel stockpile cap +50% |
| 4 | Jump Logistics | supply range +1 lane; depot T3 output +25% |
| 5 | Autonomous Fleets | freighter upkeep -25% |
| 5 | Galactic Logistics | +1 sector cap; freighter speed +15% |

## Society: growth, stability, diplomacy, alien relations
| Tier | Tech | Effect / unlocks |
|---|---|---|
| 1 | Planetary Administration | stability +3 |
| 1 | Hydroponics | food output +10% |
| 1 | Research Grants | Researcher output +10% |
| 2 | Xenobiology | habitability +100‰ on non-ideal planet types |
| 2 | Public Health | pop growth +15% |
| 2 | Diplomatic Corps | influence +1 per month; unlocks the Research Pact treaty |
| 2 | Urban Planning | housing +2 per colony |
| 3 | Distributed Research | +1 research slot (B14) |
| 3 | Interspecies Relations | opinion +5 with every empire you have contact with |
| 3 | Information Treaties | unlocks the Intel Sharing treaty |
| 3 | Academies | Research Station output +50%; Academy World synergy +50‰ |
| 4 | Arcology Projects | housing +5 per colony |
| 4 | Galactic Standards | trade income +15%; deals value +10% for partners |
| 4 | Sector Governance | +1 sector cap; stability +3 |
| 5 | Post-Scarcity Society | job output +10% (all jobs) |
| 5 | Galactic Citizenship | Council votes +1; Reputation +50 |

## Military Doctrine: formations, doctrine options, veterancy, boarding
| Tier | Tech | Effect / unlocks |
|---|---|---|
| 1 | Fleet Drills | ship accuracy +3% |
| 1 | Damage Control | ship hull repair +25% |
| 1 | Point Defence Grids | point defence +10% |
| 2 | Missile Guidance | unlocks Missile Pod Mk II, Torpedo Mk II |
| 2 | Electronic Warfare | unlocks ECM Suite Mk II |
| 2 | Boarding Tactics | marines +25%; unlocks Marine Barracks Mk II |
| 2 | Fortification | planetary defence and defence platform hull +20% |
| 3 | **Carrier Doctrine Mk II** | carrier and assault ship Mk II hulls; unlocks Fighter Wing Mk II |
| 3 | **Shock Doctrine** (excl. Attrition) | damage +10% in the first 3 rounds |
| 3 | **Attrition Doctrine** (excl. Shock) | morale loss -20%; retreat losses -25% |
| 3 | Veteran Crews | veterancy gain +50% |
| 4 | Point Defence Mk II | unlocks Point Defence Mk II |
| 4 | Stealth Plating | unlocks the Stealth Plating component (signature -20) |
| 4 | Combined Arms | fleets with 3+ hull classes: accuracy +5% |
| 5 | **Carrier Doctrine Mk III** | carrier and assault ship Mk III hulls |
| 5 | Total War Doctrine | war exhaustion -25%; War Footing transition 30 days |

## Xeno Studies: alien tech integration, reverse engineering
| Tier | Tech | Effect / unlocks |
|---|---|---|
| 1 | Xenolinguistics | first contact gives intel level 1 on that empire |
| 1 | Salvage Analysis | tech fragments from battles +25% |
| 1 | Alien Materials | Exotics deposit output +10% |
| 2 | Reverse Engineering | reverse engineering available (B14: 100 fragments, 70 for humans) |
| 2 | Xenopsychology | espionage mission success +10% |
| 2 | Captured Tech Study | fragments from captured ships x2 |
| 2 | Alien Habitats | habitability +100‰ for non-founder pops |
| 3 | Adaptive Integration | reverse-engineered techs cost 40% instead of 50% |
| 3 | Counter-Intelligence | enemy agent detection +25% |
| 3 | Signal Analysis | intel level gains +25% |
| 3 | Xenoarchaeology | +5 fragments per month per explored anomaly (anomalies arrive in M7; until then, none) |
| 4 | Hybrid Technology | human-adapted variants available for unlocked alien techs |
| 4 | Precursor Studies | Exotics output +25% |
| 4 | Deception Networks | false signatures: your fleets show 1 intel level lower to others |
| 5 | Unified Theory | research +15% (all branches) |
| 5 | Xeno Synthesis | one extra reverse-engineering unlock per faction |

## Species nodes (species_only)
| Species | Tier / branch | Tech | Effect |
|---|---|---|---|
| Humans | 2 Military Doctrine | Field Improvisation | refit time -50%; human-adapted variants available without Hybrid Technology |
| Vess'kar | 2 Physics | Ancient Archives | research +10%; Energy Mastery costs -25% |
| Krothi | 2 Society | Swarm Nurseries | pop growth +20% |
| Ohlan | 3 Logistics | Shadow Convoys | freighter signature -15 (harder to detect, D12) |
| Thessari | 3 Engineering | Bastion Matrices | defence platform shield +25% |

## New content this tree needs (built in WP3/WP4)
- Hulls: Mk II and Mk III for 8 classes x 5 species (80); Fast Courier; Salvage Tug.
- Components: Mk II of railgun, autocannon, pulse laser, heavy laser, missile pod, torpedo, shield,
  armour, ECM, point defence, marines, fighters; Mk III railgun, mass driver, heavy laser, shield, armour;
  Plasma Lance (+Mk II); Salvage Bay; Stealth Plating.
- Stations/buildings: Listening Post T2/T3 (T1 free), Research Station (free), Deep Space Array;
  Foundry II and Fabricator II.
- Modifier keys for the new effects (sensor strength, supply range, research, build time and so on).
