# DEATHWORLDERS — Sub-spec F: UI & UX

*Version 0.3 (Control Room style; Fleet Command OS concept; three instruments). Companion to the main Game Design Spec v1.1 (sections 3, 15, 16.7) and Sub-specs A–E. Wireframes are layout sketches, not visual design.*

**Change log**
- 2026-09-30 (M1 WP1): F17 gains `open_menu` = F10 (controller binding tbd). Esc stays `view_up` only; there is no Esc fallback to the menu at the Galaxy view.
- 2026-10-01 (M1 WP8): F17 gains `dive` = Enter / keypad Enter (enter whatever is under the centre reticle;
  needed for keyboard-only navigation, `ui_accept` can't be used because it includes Space = pause),
  `zoom_in` / `zoom_out` also on PageUp / PageDown, and `pan_drag` = middle mouse. Right-click orders the
  selected unit to the system under the cursor; with no unit selected it backs out (like `view_up`).
- 2026-10-01 (M1 WP9) F21: the Theme is built at runtime from `ui/themes/tokens.json`
  (`ControlRoomTheme`) instead of a saved `control_room.tres`, so palettes swap without a re-export.
  Fonts bundled in `assets/fonts/` with their OFL texts. Glass blur is not implemented yet (flat
  translucent panels). `open_outliner` = Tab is in the InputMap; Esc returns focus to the map.

---

## F1. UX Principles

1. **The map is the game.** Panels slide over the map edges; the centre stays visible. No full-screen panel except Research, Designer, Diplomacy and Battle Report.
2. **Three clicks to anything.** Any entity reachable from the outliner, map, or search in ≤ 3 actions.
3. **Explain every number.** Every value has a **breakdown tooltip** (source list, same as modifier resolution in Sub-spec C4). Tooltips can nest (hover or focus-hold a term inside a tooltip).
4. **Exceptions, not dashboards.** Alerts (Sub-spec D6) drive attention; routine information stays one level down.
5. **Controller-ready from day one** (main spec 16.7): all UI focus-navigable, no hover-only info, minimum 1280×800.
6. **Colour-blind safe.** Never colour alone: every state also has an icon or pattern. Empire colours chosen from a CB-safe palette with distinct markers.
7. **Control Room style** (F21): ultra-minimalist greyscale, a bright white room with floating glass panels and dark ink. Colour is reserved for urgency.

---

## F2. Global HUD Layout

```
┌──────────────────────────────────────────────────────────────┐
│ TOP BAR                                                      │
│ [Emblem] ⚙Alloys 1,240  ⬡Comp 310  🌾Food +12  ₵ 2,140 +19   │
│ ⚗ 55 RP  ✦ Infl 42 +3   │ 14 Mar 2203 │ ❚❚ ▶ ▶▶ ▶▶▶ │ ⚠ 3  │
├───────────┬──────────────────────────────────────┬───────────┤
│ LEFT      │                                      │ RIGHT     │
│ CONTEXT   │                                      │ OUTLINER  │
│ PANEL     │              MAP VIEW                │ ▸ Fleets  │
│ (selected │       (Galaxy / Cluster / Solar)     │ ▸ Sectors │
│  entity)  │                                      │ ▸ Planets │
│           │                                      │ ▸ Convoys │
│           │                                      │ ▸ Builds  │
│           │                                      │ ▸ Research│
├───────────┴──────────────────────────────────────┴───────────┤
│ BOTTOM: [Map modes ▾] [Breadcrumb: Galaxy › Orion › Sol]     │
│ Event ticker ···  Battle report: Kepler — Victory ▸          │
└──────────────────────────────────────────────────────────────┘
```

- **Top bar resources:** shows **empire totals as a summary**, but because goods are local, clicking a resource opens the **Stockpile view** (F9) showing where it actually is.
- **⚠ Alerts button** with count; opens the Alerts panel (F12).
- **Breadcrumb** doubles as view navigation.
- **Co-op:** a role badge next to the emblem (Admiral / Chancellor…) and partner cursor pings on the map.

---

## F3. Map Views & Map Modes

| View | Default content | Click | Double-click / zoom |
|---|---|---|---|
| Galaxy | Clusters, corridors, borders, fleet group icons | Select cluster/fleet | Enter cluster |
| Cluster | Systems, lanes, fleets, convoys, ghosts | Select system/fleet | Enter system |
| Solar | Star, planets, stations, ships, debris fields | Select object | — |

**Map modes** (bottom-left selector, hotkeys 1–9):

| # | Mode | Shows |
|---|---|---|
| 1 | Political | Borders, owners |
| 2 | Logistics | Trunk & local routes, traffic thickness, bottlenecks in red |
| 3 | Supply | Supply range overlay per depot, out-of-supply fleets |
| 4 | Intel / Fog | Knowledge levels, sensor coverage, ghosts with age |
| 5 | Sectors | Sector areas, hubs, reach rings (D9) |
| 6 | Security | Security heatmap, pirate activity |
| 7 | Diplomacy | Opinion colouring toward you |
| 8 | Resources | Deposits and stockpile fill levels |
| 9 | Military | Fleet strengths, fortifications, threats |

---

## F4. Context Panel: Planet

```
┌──────────────────────────────┐
│ MARS  ◆ Developed  [Pin][⋯]  │
│ Desert · Medium · Sol        │
│ Traits: 🛡 Unbroken  ⚒ Forge… │
├──────────────────────────────┤
│ Focus: Industrial ▸ Mining   │
│ Autonomy: [Auto|Assist|Man]  │
│ Template: Forge World v2     │
├──────────────────────────────┤
│ Pops 14/20  Stability 62 ▲   │
│ Jobs  Wrk 6 Min 4 Farm 3 +1  │
├──────────────────────────────┤
│ Stockpile (local)            │
│ Ore 320 ▮▮▮▯  Alloys 90 ▮▯▯▯ │
│ Food 140 ▮▮▯▯ …   [more]     │
├──────────────────────────────┤
│ Buildings 5/6  [+ queue]     │
│ Orbitals: Shipyard S · Mine  │
├──────────────────────────────┤
│ [History timeline ▸]         │
└──────────────────────────────┘
```
- In **Automated** mode, build controls are collapsed; a "Governor plans: Foundry (42 days)" line shows intent.

## F5. Context Panel: Fleet

```
┌──────────────────────────────┐
│ 2nd Fleet "Hammer"  Adm. Ncube│
│ 12 ships · Str ▮▮▮▮▯ · Vet   │
│ Supply: ● In range (Sol Dep) │
│ Ammo ▮▮▮▯  Fuel ▮▮▮▮         │
├──────────────────────────────┤
│ Doctrine                     │
│ Range   [Standoff|Line|Close]│
│ Target  [Escorts first ▾]    │
│ Retreat [50% ▾]              │
│ Stance  [Balanced ▾]         │
├──────────────────────────────┤
│ Composition                  │
│ ▸ TF Alpha  4 Cruisers       │
│ ▸ TF Bravo  6 Destroyers     │
│ ▸ Screen    2 Frigates       │
├──────────────────────────────┤
│ [Move] [Patrol] [Escort]     │
│ [Refit ▸] [Merge] [Split]    │
└──────────────────────────────┘
```
- **Refit** opens a refit picker listing the fleet's designs with alternatives and the enemy intel profile side by side (F10).

---

## F6. Sector Screen (sectors are the main management unit)

```
┌─────────────────────────────────────────────────────────────┐
│ KEPLER SECTOR   Hub: Kepler Station T2   Gov: Aliyu (Logist.)│
│ Directive: [Industrial Core ▾]   Systems 9 · Planets 7       │
├──────────────────────────────┬──────────────────────────────┤
│ PLANETS                      │ SECTOR STOCKPILE & TRADE     │
│ Name    Stage  Focus  Stab ⚙ │ Res     Stock  Net   Export% │
│ Kepler2 Core   Ind/Log 71 A  │ Alloys  840   +44   [60%]   │
│ Arden   Dev    Min/Ind 58 A  │ Ore     1,210 +12   [50%]   │
│ Tessa   Colony  —      49 A  │ Food    300   −6 ⚠  [ 0%]   │
│ Hollow  Outpost —      —  —  │ Comp    95    +8    [30%]   │
│ …                            │ [Import request ▸]           │
├──────────────────────────────┴──────────────────────────────┤
│ FREIGHT: 14/18 berths · Utilisation 81% · 0 convoys lost    │
│ ALERTS (2): Food deficit in 4 mo · Shipyard idle (Arden)    │
└─────────────────────────────────────────────────────────────┘
```
`A` = Automated, `S` = Assisted, `M` = Manual.

## F7. Logistics Manager

Tabs: **Trunk routes · Demand targets · Hubs & freighters · Losses**

```
┌─────────────────────────────────────────────────────────────┐
│ TRUNK ROUTES                                    [+ Route]   │
│ From        → To          Res     Qty/mo  Prio  Safety  St  │
│ Kepler Hub  → Sol Hub      Alloys  120     ●●○   Lane    ✔   │
│ Sol Hub     → Vega Depot   Munit.   80     ●●●   Avoid   ⚠   │
│ Orion Hub   → Sol Hub      Food     60     ●○○   Warp    ✔   │
├─────────────────────────────────────────────────────────────┤
│ Selected: Sol → Vega Depot                                  │
│ 3 freighters assigned · round trip 34 d · throughput 71/mo  │
│ ⚠ Demand 80/mo exceeds throughput (−9)  [Add freighter]     │
│ Path: Sol ─ Barnard ─ ▲Wolf (pirates) ─ Vega [Show on map]  │
└─────────────────────────────────────────────────────────────┘
```
- Every route shows **throughput vs demand**, the Sub-spec B7 formula made visible.

## F8. Colonise / Expand Screen

```
┌──────────────────────────────────────────┐
│ COLONISE: Tessa (Arctic, Small)          │
│ Habitability (Human) 70% · Housing 8     │
│ Source pop: Kepler2 (−1 pop)             │
│ Reach: 2 (Kepler Hub) ✔                  │
│ Upkeep: 5 ₵/mo + food until Farm         │
│ Estimated payback: ~7 years (2211)       │
│ Sector directive → default: Farm/Mining  │
│                 [Cancel]  [Colonise ▸]   │
└──────────────────────────────────────────┘
```

## F9. Stockpile View (where are my goods?)

A sortable table of every stockpile (planets, hubs, depots, stations) with fill bars, plus a map overlay (mode 8). Filters: resource, sector, "near full", "empty". It answers the question the global resource bar can't: *"I have 1,240 alloys, but where?"*

---

## F10. Ship Designer (full screen)

```
┌─────────────────────────────────────────────────────────────┐
│ DESIGNER   Hull: [Human Cruiser Mk I ▾]   Design: Hammer v3 │
├──────────────┬───────────────────────────┬──────────────────┤
│ SLOTS        │      3D PREVIEW           │ STATS            │
│ W-M1 Railgun │   (low-poly model with    │ Hull 1500        │
│ W-M2 Railgun │    hardpoints highlighted,│ Armour 140       │
│ W-S1 Autocan │    turrets swap live)     │ Shield 450       │
│ D-1 Armour   │                           │ Evasion 80       │
│ D-2 Shield   │                           │ DPS L/M/C        │
│ U-1 Sensor   │                           │  40 / 180 / 200  │
│ C-1 Reactor  │                           │ Cost 260⚙ 60⬡    │
├──────────────┴───────────────────────────┴──────────────────┤
│ COMPONENT PICKER (for selected slot)   [Kinetic|Energy|Mis.]│
│ Railgun M  100×1  pen30  ✔ │ Heavy Laser 100×1 ✔ │ …        │
├─────────────────────────────────────────────────────────────┤
│ VS KNOWN ENEMY: [Krothi 3rd Swarm ▾] intel L3               │
│ Predicted: favourable ▲ (armour-light, no PD)               │
│ [Save] [Save as] [Export code] [Import] [Set as refit]      │
└─────────────────────────────────────────────────────────────┘
```
- **Predicted matchup** runs a quick headless battle sim (Sub-spec A) against the known intel profile. It's the in-game payoff of intel, shown with honest uncertainty at low intel levels.

## F11. Battle Report (full screen)

```
┌─────────────────────────────────────────────────────────────┐
│ BATTLE OF KEPLER · 14 Mar 2203 · DECISIVE VICTORY           │
│ Terran 2nd Fleet (Adm. Ncube) vs Krothi 3rd Swarm           │
├───────────────────────────────┬─────────────────────────────┤
│ STRENGTH OVER TIME            │ LOSSES                      │
│ ██████▇▇▆▅▅▄▄▃ Terran          │ Terran  2 destroyers        │
│ ██████▅▄▃▂▁▁  Krothi          │ Krothi  23 corvettes, 4 car │
│ L───────M──────C  (phases)    │ Salvage field created ▸     │
├───────────────────────────────┴─────────────────────────────┤
│ WHAT WORKED                                                 │
│ • Kinetics vs Krothi armour-light hulls: 71% of damage      │
│ • Enemy fighters: 64% intercepted by your PD                │
│ KEY MOMENTS                                                 │
│ • Round 9: ISS Vanguard rammed the swarm-mother             │
│ • Round 14: Krothi screen broke; swarm routed               │
│ LESSONS & INTEL                                             │
│ • Intel on Krothi 3rd Swarm raised to L4                    │
│ HONOURS  MVP: ISS Vanguard · Adm. Ncube +XP · 3 promoted    │
│ [View on map] [Save to archive] [Close]                     │
└─────────────────────────────────────────────────────────────┘
```

## F12. Alerts Panel

```
┌──────────────────────────────────────────────┐
│ ALERTS (3)                     [Mute ▾]      │
│ 🔴 Starvation in 60 days — Tessa  [Fix ▸]    │
│ 🟠 Convoy lost — Sol→Vega (Wolf)  [Escort ▸] │
│ 🟡 Shipyard idle — Arden          [Queue ▸]  │
└──────────────────────────────────────────────┘
```
- **[Fix ▸]** shows a one-line preview of the Command before issuing it ("Route 40 food/month from Kepler2 → Tessa").
- Co-op: alerts route to the role that owns the relevant commands.

## F13. Research Tree (full screen)

- Branch tabs across the top (Physics, Engineering, Logistics, Society, Doctrine, Xeno).
- Horizontal tiers left→right; **species nodes** outlined in the species colour; **exclusive choices** shown as forked pairs with a lock icon.
- Two (later three) **research slots** at the bottom with progress and ETA.
- Search box; "path to" feature: select a target tech and it highlights the prerequisite chain and queues it.
- Tech fragments shown per alien faction with progress bars toward reverse-engineering unlocks.

## F14. Diplomacy Screen (full screen)

```
┌─────────────────────────────────────────────────────────────┐
│ EMPIRES          │ VESS'KAR ASCENDANCY   Aloof Elders       │
│ ▸ Vess'kar  −12  │ Opinion −12  ▸breakdown  Trust 34        │
│ ▸ Ohlan     +38  │ Power (est.) 40–70 ships · intel L2      │
│ ▸ Krothi    −55  │ Treaties: Non-aggression (3 yrs left)    │
│ ▸ Thessari  +61  │──────────────────────────────────────────│
│ MINORS           │ PROPOSE: [Trade agreement ▾]             │
│ ▸ Oru (prot.)    │ Acceptance: −6  ✖                        │
│ COUNCIL ▸        │   +(−6) Opinion  +17 Trust  −15 Treaty   │
│ NON-STATE ▸      │   +10 Deal balance  −12 Personality      │
│                  │   Tip: +6 needed — add a gift or wait    │
│                  │ [Deal builder ▸] [Propose]               │
└─────────────────────────────────────────────────────────────┘
```
- **Acceptance breakdown** always visible (Sub-spec E5).
- **Deal builder:** two columns (you give / they give); physical goods show delivery time and route risk.
- **Council tab:** session countdown, active resolutions, vote tallies with each member's expected vote.

## F15. Match Setup

Two columns: **Galaxy** (size, shape, pace, seed, crisis, fog, victory toggles, starting position) and **Players** (slots with species, human/AI, difficulty, team, co-op role). A mini-map preview regenerates live from the seed. MP lobby adds a ready check and a mod-list comparison with mismatches in red (main spec 18b).

## F16. Co-op Role HUD

- Role badge + a role-filtered outliner (Admiral sees fleets/armies first).
- **Requests inbox**: incoming requests from the partner ("6 cruisers at Sol by March") with Accept / Counter / Decline.
- Map pings: `Ping` action + radial of ping types (Attack here, Defend, Need supply, Look).

---

## F17. Input Map (PC now, controller later)

| Action | Mouse/KB | Controller (future) |
|---|---|---|
| select | LMB | A |
| context_action | RMB | X |
| zoom_in / out | Wheel | RT / LT |
| pan | WASD / edge / MMB drag | Left stick |
| view_up | Esc / Backspace | B |
| pause | Space | Start |
| speed_up / down | + / − | RB / LB |
| open_menu | F10 | (tbd) |
| dive | Enter | A (tbd) |
| pan_drag | MMB drag | (none) |
| map_mode_1…9 | 1–9 | D-pad radial |
| open_outliner | Tab | Y (hold) |
| open_alerts | A | Back |
| search | Ctrl+F | L3 |
| ping (co-op) | Alt+Click | R3 |

---

## F18. Visual Language

Superseded by the Control Room style in F21. The meaning-carrying rules still hold, now expressed in greyscale:

| Element | Rule |
|---|---|
| Resources | Line icons (1.4 px stroke), not colours: Alloys ▲ triangle, Components hexagon, Food sprout, Ore pick, Exotics spark, Munitions chevron, Fuel drop, Credits coin, Research flask, Influence star |
| Empires | Border **pattern** (solid, dashed, dotted, hatched, double) + emblem; optional desaturated tint on the map only |
| Knowledge levels (D12) | Unknown: no ink · Explored: `ink-3` + "as of" date · Covered: `ink-1` |
| Ghosts | Dashed hollow marker, fades with age, timestamp label |
| Alert severity | Urgent: `signal` red dot · Soon: filled ink dot · Info: hollow ink dot |
| Selection | Inversion: `ink-1` fill with light text |
| Numbers | Monospace light, tabular figures, signed deltas |

## F19. Accessibility & Comfort

- UI scale 75–150%; text scale separate.
- Colour-blind modes (deuteranopia, protanopia, tritanopia) swap palettes; icons carry meaning regardless.
- Reduce motion: disables camera easing and animated map effects.
- Pause-on-events filter (e.g. auto-pause on war declaration, first contact, crisis) in single-player.
- All tooltips pin-able.

## F20. Milestone Mapping

| Milestone | UI delivered |
|---|---|
| M1 | HUD shell, 3 views, breadcrumb, match setup, context panel (system/planet basics) |
| M2 | Planet panel, Sector screen, Logistics Manager, Stockpile view, Colonise screen, Alerts |
| M3 | Fleet panel, Ship Designer, Battle Report |
| M4 | Diplomacy screen, Council tab |
| M4.5 | MP lobby, co-op role HUD |
| M5 | Research tree, Intel/Fog map mode |
| M6 | Invasion UI (ground forces panel, ground battle report) |
| M7 | Traits history timeline, Legend panel, event popups |

## F21. Visual Style: "Control Room"

*Inspiration: the ultra-minimalist greyscale control room from The Matrix Revolutions: a limitless white space, operators at floating translucent displays, dark ink on light glass. We borrow the mood, not any specific imagery. Mockup: "Deathworlders — Control Room UI style" artifact.*

### Principles
1. **Light is the background, information is ink.** The UI and the strategic map (Galaxy, Cluster) sit in a bright off-white void with soft edge falloff.
2. **Panels float.** Translucent glass (blur ~14 px), rounded 10 px, no borders, one broad soft shadow. Panels never touch screen edges.
3. **Colour is a signal, not decoration.** Everything is greyscale except the single `signal` red for "act now" (urgent alerts, active threats). Empire identity uses patterns and emblems first.
4. **Selection inverts.** Selected rows, active toggles and the current speed become dark ink fills with light text.
5. **Quiet motion.** Fades and eases only; the one looping animation allowed is a slow pulse on an urgent map threat. Reduce-motion disables it.

### Tokens (Godot `Theme` + shader params)

| Token | Light (default) | Dark variant | Use |
|---|---|---|---|
| `void` | #EEF0F0 | #1C1E1F | Map/UI background |
| `void_deep` | #E3E6E6 | #141516 | Vignette edge |
| `panel` | #FAFBFB @ 78% | #26292B @ 78% | Floating panels |
| `hair` | #CDD1D2 | #3E4345 | Hairlines, lanes, rings |
| `ink_1` | #26292B | #E8EBEC | Primary text, selection fill, systems |
| `ink_2` | #686E71 | #9AA0A3 | Secondary text, labels |
| `ink_3` | #A2A8AB | #62686B | Tertiary, disabled, stale data |
| `signal` | #B8322A | #E0574E | Urgent only |
| `territory` | ink @ 6% | ink @ 6% | Own territory wash |

The dark variant is a setting (night use, accessibility), not the default.

### Typography
- **UI:** Jura (Light 300 / Regular 400 / Medium 500 / SemiBold 600), open licence (OFL), bundled with the game.
- **Numbers:** IBM Plex Mono Light (OFL), tabular figures.
- Sentence case everywhere; no all-caps labels. Minimum 14 px at 1280×800 (F18 rule stands).

### The map in this style
- Galaxy/Cluster views: stars and systems as ink dots sized by importance, lanes as hairlines, trunk routes as thicker ink, convoys as small diamonds, fleets as chevrons, range rings as faint concentric hairlines.
- Own territory: faint ink wash with a dashed ink border; rivals: hatched/dotted patterns.
- **Solar view (3D), decided:** the same white room: a bright void environment with soft fog, low-poly models rendered in greys with the FACTION surface shaded by pattern-friendly light tint, engines as soft white glow. The planet shader uses greyscale terrain bands. It is told apart from the other views by the instrument rules in F22.

### Godot implementation notes
- One `Theme` resource (`ui/themes/control_room.tres`) generated from a token table (`ui/themes/tokens.json`) so light/dark and mods can swap palettes.
- Panels: `PanelContainer` with a `StyleBoxFlat` (bg `panel`, corner radius 10, shadow size ~24, shadow colour ink @ 10%) over a `BackBufferCopy` + blur shader for the glass effect (toggle off on low-end/Deck if needed).
- Map rendering reads tokens from the same table; the 3D environment uses a light `Environment` background + fog colour = `void`.
- Faction tint: the `FACTION` material surface takes the empire's pattern colour at low saturation; patterns (stripes/dots) come from a triplanar decal shader so empires stay distinguishable in greyscale.

## F22. Concept: The Fleet Command OS

The whole game is presented as the operating system a real admiral would use to direct a war. Every screen is an instrument of that OS; the player never sees "game UI", only their command console. This is the frame for all visual and copy decisions.

### Three instruments, one room
The three map views share the white room but are instantly distinguishable by **grid, projection and depth**, not by colour.

| | Strategic plot (Galaxy) | Operational plot (Cluster) | Tactical scope (Solar) |
|---|---|---|---|
| Projection | Flat, orthographic | Flat, orthographic | 3D perspective, tilted ~22° over the ecliptic |
| Grid | Square coordinate grid, lettered columns and numbered rows (grid refs like "E5") | Concentric range rings from the selected hub | Polar scope: orbit ellipses plus a bearing ring with ticks every 10° and labels at 000/090/180/270 |
| Void tone | Lightest, flat | Mid, soft vignette | Deepest vignette around a circular scope, reticle corner brackets |
| Content | Clusters, theatres, armadas | Systems, lanes, routes, fleets, convoys | Planets, stations, ships, contacts, debris |
| Depth cues | None | None | Drop lines from ships to the ecliptic with a cross at the plane point; altitude in AU on the label |
| Readout | Grid scale ("Grid square 1,000 ly") | Scale bar ("1 lane") | Scope readout: range, bearing, elevation |
| Title | "Strategic plot" | "Operational plot" | "Tactical scope" |

**Transitions:** zooming between instruments morphs the grid (square grid dissolves into range rings, rings tilt into the scope), about 400 ms, disabled by reduce-motion.

### Military symbology (APP-6-inspired frames)
Allegiance is carried by **frame shape**, so the greyscale rule never costs information:

| Allegiance | Frame | Notes |
|---|---|---|
| Friendly (you and co-op partners) | Rounded rectangle | Solid |
| Allied | Rounded rectangle, double outline | |
| Hostile (at war) | Diamond | Solid |
| Neutral | Square | |
| Unknown / unidentified contact | Four-lobed "clover" | Dashed; "?" until intel level 2 |
| Stale (ghost, D12) | Same frame, dashed, faded | Timestamp label |

Inside the frame: a domain glyph (space: chevron; ground: crossed lines; station: small square; civilian/freighter: diamond dot). Above the frame, **echelon marks** show formation size:

| Naval | Mark | Ground | Mark |
|---|---|---|---|
| Squadron | I | Company | I |
| Task Force | II | Battalion | II |
| Fleet | X | Brigade | X |
| Armada | XX | Army | XX |

### Signals as military message precedence
Alert severity (D6, F12) uses message precedence labels:

| Precedence | Meaning | Treatment |
|---|---|---|
| FLASH | Act now (convoy lost, planet invaded, crisis) | `signal` red outline tag, auto-pause option |
| IMMEDIATE | Within weeks (starvation forecast, supply warning) | Dark ink tag |
| PRIORITY | Needs a decision soon (idle shipyard, unrest) | Outline ink tag |
| ROUTINE | Informational (research done, construction complete) | Log only |

Precedence tags are the one place all-caps is used, because they mimic real message headers.

### Diegetic touches
- Top bar reads as the command console: "Terran Union Fleet Command" (or the player's species' equivalent).
- The event ticker is a **comms log** with timestamps and message numbers ("0914 After-action report 231: Battle of Kepler, decisive victory").
- Battle reports are **after-action reports** with serial numbers; saves are the **archive**; the main menu is a **login** to the command network.
- Every number shows its **provenance** when fog applies ("as of 3 months ago", intel level), matching the knowledge model (D12).
- Co-op partners appear as other officers on the network ("Chancellor online") with their role badges.
- Loading screens are short **boot sequences** (a few lines of system checks), skippable.
- UI sounds: soft, dry console ticks and confirmations; FLASH traffic gets one distinct tone.

