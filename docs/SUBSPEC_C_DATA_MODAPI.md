# DEATHWORLDERS — Sub-spec C: Data Schemas & Mod API

*Version 0.1. Companion to the main Game Design Spec v1.0 (sections 16, 18, 18b) and Sub-specs A & B. Target: Godot 4.x, GDScript.*

---

## C0. Principles

1. **Everything is data first.** If a designer or modder can express it as a Def, it is not code.
2. **Stable string IDs everywhere.** Nothing references content by index, file path, or display name.
3. **The base game is the `core` mod.** Same loader, same schemas, same tools as modders.
4. **Defs are immutable after load.** Runtime state references Defs by ID; it never edits them.
5. **The sim is only changed by Commands.** Players, AI, scenarios, and script mods all go through the same door.
6. **Determinism is non-negotiable.** Integer maths, ordered iteration, seeded RNG streams (Sub-spec A0).

---

## C1. IDs

**Format:** `<mod_id>:<category>/<name>`

```
core:hull/human_cruiser_mk1
core:weapon/railgun_m
core:species/krothi
core:tech/physics_kinetic_2
myshipsmod:hull/human_dreadnought
```

- `mod_id`: lowercase `[a-z0-9_]`, unique per mod.
- `category`: fixed list (C3).
- References may omit `mod_id` when pointing at the same mod (`hull/human_cruiser_mk1` inside `core`).
- Stored as `StringName` at runtime (interned, fast comparison).
- At load, the Database also builds a **dense int index** per category (sorted by ID) for hot loops. Int indices are **never saved** or sent over the network; they differ with mod sets.

---

## C2. Def Base

```gdscript
# res://sim/defs/def.gd
class_name Def
extends Resource

@export var id: StringName              # "core:hull/human_cruiser_mk1"
@export var name_key: String            # localisation key
@export var desc_key: String
@export var icon: String                # res:// or mod-relative path
@export var tags: Array[StringName] = []
@export var modifiers: Array[ModifierDef] = []   # passive effects (C4)

var source_mod: StringName              # set by loader, not authored

func validate(db: Database) -> Array[String]:
	return []   # subclasses return error strings
```

Every schema below extends `Def`. Authoring formats:
- **`.tres`** (Godot Resource): used by `core`, editable in the Godot inspector.
- **`.json`**: first-class for modders; the loader converts it to the same Resource types.

---

## C3. Def Catalogue

| Category | Def | Key fields |
|---|---|---|
| `resource` | ResourceDef | `physical: bool`, `base_value: int`, `stockpile_default_cap: int` |
| `species` | SpeciesDef | `traits[]`, `habitability{planet_type: permille}`, `starting_ftl`, `hull_set[]`, `ground_unit_set[]`, `signature_mechanic: StringName`, `ai_personality`, `event_packs[]`, `home_template` |
| `trait` | TraitDef | `modifiers[]`, `opposes[]` |
| `planet_type` | PlanetTypeDef | `terrain`, `size_weights{}`, `deposit_table[]`, `color`, `shader_params{}` |
| `terrain` | TerrainDef | `ground_mods{unit_type: permille}`, `attrition_permille`, `adapted_habitability` |
| `job` | JobDef | `outputs{res: int}`, `inputs{res: int}`, `stability: int` |
| `building` | BuildingDef | `jobs{job: count}`, `cost{res: int}`, `build_days`, `upkeep{}`, `requires_tech[]`, `requires_focus` |
| `focus` | FocusDef | `boosted_jobs[]`, `bonus_permille`, `modifiers[]` |
| `synergy` | SynergyDef | `focus_a`, `focus_b`, `bonus_permille`, `modifiers[]` |
| `station` | StationDef | `tiers[]` (cost, days, storage, berths, weapons), `placement[]`, `function` |
| `hull` | HullDef | see C5 |
| `component` | ComponentDef | see C5 |
| `weapon_family` | WeaponFamilyDef | `shield_mult`, `armor_eff`, `interceptable`, `uses_ammo` |
| `ground_unit` | GroundUnitDef | `unit_type`, `attack`, `defense`, `org_max`, `width`, `cost{}`, `specials[]` |
| `ground_type` | GroundTypeDef | `matchups{other_type: permille}` |
| `doctrine` | DoctrineDef | `domain: space/ground`, `modifiers[]`, `range_pref`, `retreat_threshold`, `target_priority` |
| `tech` | TechDef | `branch`, `tier`, `cost`, `prereqs[]`, `exclusive_with[]`, `unlocks[]`, `modifiers[]`, `species_only[]` |
| `leader_trait` | LeaderTraitDef | `role`, `modifiers[]`, `rarity` |
| `treaty` | TreatyDef | `influence_cost`, `requires_opinion`, `effects[]`, `break_penalty` |
| `event` | EventDef | see C8 |
| `crisis` | CrisisDef | `warning_events[]`, `spawn_rules`, `ai_behaviour`, `victory_share_rules` |
| `scenario` | ScenarioDef | `map`, `players[]`, `start_state`, `objectives[]`, `triggers[]` |
| `modifier_key` | ModifierKeyDef | declares a modifiable stat (C4) |
| `crew_role` | RoleDef | co-op role permissions: `command_ids[]` |

---

## C4. The Modifier System (the backbone of moddability)

All bonuses from traits, techs, focus, leaders, doctrines, terrain, events and mods are **Modifiers** applied to **Modifier Keys**.

```gdscript
# res://sim/defs/modifier_def.gd
class_name ModifierDef
extends Resource
enum Mode { ADD, PERMILLE }
enum Scope { OWNER, EMPIRE, PLANET, SYSTEM, FLEET, SHIP, UNIT }
@export var key: StringName        # "ship.accuracy.missile"
@export var mode: Mode = Mode.ADD  # flat, or summed %
@export var value: int             # 100 = +10% in PERMILLE mode
@export var scope: Scope = Scope.OWNER
@export var condition: Dictionary = {}   # optional, same DSL as events (C8)
```

**Resolution** (matches Sub-spec A0):
```
final = (base + sum(ADD)) * (1000 + sum(PERMILLE)) / 1000
```

- Modifier keys are **declared** (`ModifierKeyDef`) with a default, min/max clamp and the scope they apply at. Unknown keys fail validation.
- Core examples: `ship.accuracy.<family>`, `ship.damage.<family>`, `ship.hull_max`, `ship.evasion`, `fleet.morale_resist`, `job.output.<job>`, `planet.stability`, `planet.housing`, `freighter.capacity`, `research.cost.<branch>`, `ground.attack.<unit_type>`.
- Mods add new keys; script mods can read them in hooks.
- **Caching:** modifier sums are cached per entity and invalidated by a dirty flag when sources change (tech researched, leader assigned, etc.).

---

## C5. Ships: HullDef & ComponentDef

```gdscript
# res://sim/defs/hull_def.gd
class_name HullDef
extends Def
@export var species: StringName            # "core:species/human"
@export var hull_class: StringName         # "cruiser"
@export var mark: int = 1
@export var size: int                      # S, M, L, XL
@export var hull: int
@export var armor: int
@export var shield: int
@export var evasion: int
@export var speed: int
@export var crew: int
@export var slots: Array[SlotDef] = []     # fixed layout
@export var cost: Dictionary = {}          # {"core:resource/alloys": 260, ...}
@export var build_days: int
@export var upkeep: Dictionary = {}
@export var shipyard_size: int
@export var model: String                  # "assets/models/ships/human_cruiser_mk1.glb"
@export var requires_tech: Array[StringName] = []

# res://sim/defs/slot_def.gd  (separate file)
class_name SlotDef
extends Resource
@export var slot_type: int                 # WEAPON, DEFENCE, UTILITY, CORE, HANGAR
@export var slot_size: int                 # S, M, L
@export var hardpoint: StringName          # "HP_W_M_01" (node name in the .glb)
```

```gdscript
# res://sim/defs/component_def.gd
class_name ComponentDef
extends Def
@export var slot_type: int
@export var slot_size: int
@export var family: StringName = &""       # weapons only
@export var damage: int
@export var shots: int
@export var accuracy: PackedInt32Array     # [L, M, C] permille
@export var penetration: int
@export var tracking: int
@export var ammo_per_shot: int
@export var stat_mods: Array[ModifierDef]  # defence/utility effects (e.g. +80 armour)
@export var cost: Dictionary
@export var model: String                  # turret/module model for the hardpoint
@export var requires_tech: Array[StringName]
```

**JSON form (modder-friendly):**
```json
{
  "category": "component",
  "id": "railgun_m",
  "name_key": "COMP_RAILGUN_M",
  "slot_type": "weapon", "slot_size": "M",
  "family": "weapon_family/kinetic",
  "damage": 100, "shots": 1,
  "accuracy": [400, 750, 800],
  "penetration": 30, "tracking": 0, "ammo_per_shot": 0,
  "cost": { "resource/alloys": 40, "resource/components": 10 },
  "model": "models/turrets/railgun_m.glb",
  "requires_tech": ["tech/physics_kinetic_1"]
}
```

**Ship design (player-made, shareable; main spec 7.4):**
```json
{
  "format": 1,
  "name": "Hammer of Sol",
  "hull": "core:hull/human_cruiser_mk1",
  "slots": ["core:component/railgun_m", "core:component/railgun_m",
            "core:component/autocannon_s", "core:component/armor_plate",
            "core:component/shield_gen", "core:component/sensor_1",
            "core:component/reactor_1"],
  "mods_required": []
}
```
Export code = `base64(deflate(json))`. `slots` order matches `HullDef.slots` order.

---

## C6. Loading & Layering

### Load order
1. Read all `mod.json` manifests (C10).
2. Topological sort by `dependencies`; ties broken by `load_after` / `load_before` hints, then by `mod_id` alphabetically.
3. `core` always first.

### Operations (per Def file)
| `op` | Meaning |
|---|---|
| `add` (default) | New ID. Error if it already exists. |
| `override` | Replace the whole Def. Error if it doesn't exist. |
| `patch` | Field-level change on an existing Def. |
| `remove` | Remove the Def (dependants fail validation, so use rarely). |

**Patch syntax:**
```json
{
  "op": "patch",
  "category": "hull",
  "id": "core:hull/human_cruiser_mk1",
  "set":    { "hull": 1700, "speed": 6 },
  "add":    { "tags": ["heavy"] },
  "remove": { "tags": ["light"] },
  "adjust": { "armor": 20 }
}
```
Patches apply in load order; later mods win on `set` conflicts. Conflicts are logged in the mod report.

### Validation (after all layers applied)
- Schema check (required fields, types, enums).
- **Reference check:** every ID reference resolves.
- Tech tree check: no cycles, tiers consistent.
- Hull/model check: every `SlotDef.hardpoint` exists in the referenced `.glb`.
- Modifier keys declared.
- Errors name the mod and file; the game refuses to start a match with errors; warnings are shown in the mod manager.

### Freeze & hash
- Database is frozen (read-only).
- **`content_hash`** = hash of every `affects_sim` Def serialised in ID order. Used by MP lobby and saves (main spec 18b).

---

## C7. Commands

```gdscript
class_name Command
extends RefCounted

var type_id: StringName        # "core:cmd/move_fleet"
var player_id: int
var exec_tick: int             # set by lockstep scheduler
var payload: Dictionary        # only ints, StringNames, arrays of those

func validate(state: GameState) -> bool:   # permissions, legality, role (co-op)
	return true
func apply(state: GameState) -> void:      # the ONLY place state changes
	pass
```

- Registered in a `CommandRegistry` by `type_id`. Network and save logs contain `type_id + payload` only.
- **Co-op roles:** `RoleDef.command_ids` lists which commands a role may issue; enforced in `validate`.
- Core commands (initial list): `move_fleet`, `set_doctrine`, `refit_fleet`, `queue_ship`, `queue_station`, `queue_building`, `set_focus`, `set_route`, `set_demand_target`, `set_research`, `propose_treaty`, `respond_treaty`, `declare_war`, `invade_planet`, `colonise`, `add_design`, `choose_event_option`, `set_speed_request`, `role_request`.

---

## C8. Events: Condition & Effect DSL

Data mods can create rich events without scripts using a JSON DSL.

```json
{
  "category": "event",
  "id": "they_did_what_ramming",
  "trigger": "on_battle_resolved",
  "condition": { "all": [
      { "battle.winner_species": "species/human" },
      { "battle.key_moment": "ram" },
      { "not": { "flag_set": "seen_ramming_event" } }
  ]},
  "mean_time_days": 0,
  "title_key": "EVT_RAM_TITLE",
  "text_key": "EVT_RAM_TEXT",
  "options": [
    { "text_key": "EVT_RAM_OPT_PROUD",
      "effects": [ { "legend.add": { "fear": 50, "respect": 20 } },
                   { "flag_set": "seen_ramming_event" } ] },
    { "text_key": "EVT_RAM_OPT_DOWNPLAY",
      "effects": [ { "opinion.add_all": 5 },
                   { "flag_set": "seen_ramming_event" } ] }
  ],
  "ai_weights": [60, 40]
}
```

- **Triggers:** `on_month_tick`, `on_day_tick`, `on_battle_resolved`, `on_first_contact`, `on_planet_colonised`, `on_tech_researched`, `on_treaty_signed`, `on_war_declared`, `on_convoy_lost`, `on_crisis_stage`, plus scenario triggers.
- **Conditions & effects** are registered handlers (`ConditionRegistry`, `EffectRegistry`). Core ships ~60 of each; script mods can register new ones.
- **Mean-time events:** `mean_time_days > 0` fires randomly via the events RNG stream (deterministic).
- `ai_weights`: how AI players pick options.
- Scenario objectives and crisis stages reuse the same DSL.

---

## C9. Mod API (script mods)

Script mods ship GDScript files extending `ModScript`. They **read** the sim through a facade and **change** it only via Commands or registered effects.

```gdscript
class_name ModScript
extends RefCounted

var api: ModApi   # injected by loader

# --- lifecycle ---
func on_load() -> void: pass                       # register things here
func on_match_start(settings: Dictionary) -> void: pass

# --- sim hooks (run inside the deterministic tick) ---
func on_hour_tick(tick: int) -> void: pass
func on_day_tick(tick: int) -> void: pass
func on_month_tick(tick: int) -> void: pass
func on_battle_round(battle: BattleView) -> void: pass
func on_battle_resolved(report: BattleReportView) -> void: pass
func on_command_applied(cmd: Command) -> void: pass

# --- client-only hooks (NOT in the sim; free to use floats, UI) ---
func on_ui_ready(ui: UiApi) -> void: pass
```

### `ModApi` surface (initial)
| Area | Functions |
|---|---|
| Registration | `register_command(type_id, script)`, `register_condition(name, callable)`, `register_effect(name, callable)`, `register_modifier_key(def)`, `register_signature_mechanic(species_id, script)` |
| Queries (read-only views) | `empire(id)`, `planet(id)`, `fleet(id)`, `system(id)`, `stockpile(owner_id)`, `battles_active()`, `def(id)` |
| Actions | `issue(command)` (as the system actor), `emit_event(event_id, target)` |
| Maths | `FixedMath.mul_permille(a, p)`, `clamp`, `isqrt`, `lerp_permille` |
| Randomness | `rng(stream_name) -> DeterministicRng` (per-mod namespaced stream) |
| Storage | `mod_state(mod_id) -> Dictionary` (saved with the game; ints/strings only) |
| Logging | `log(msg)`, `warn(msg)` |

**Views** are read-only wrappers; setting a field on a view is an error.

### Determinism rules for mods
- No floats, `Time`, `OS`, file or network access inside sim hooks.
- Use only `api.rng(...)`; never Godot's global random functions.
- Iterate collections from the API (already ID-sorted).
- **Determinism test tool:** `tools/mod_determinism_test.gd` runs a match twice with the same seed and command log and diffs subsystem checksums. Mod authors run it before publishing.

### Security
- GDScript mods can technically call anything in the engine. The mod manager shows script mods with a **warning badge**; data/asset-only mods show a **safe badge**.
- MP lobbies display every mod's type.

### Signature mechanics as modules
Each species' signature mechanic (Legend, Precedence, Brood Surge, Contracts, Sanctuary) is implemented **as a `ModScript` inside `core`**, which proves the API is powerful enough and gives modders working examples.

---

## C10. Mod Package

```
mods/
└── my_mod/
    ├── mod.json
    ├── defs/            (*.json or *.tres, any subfolders)
    ├── scripts/         (*.gd, script mods only)
    ├── models/          (*.glb)
    ├── textures/
    ├── audio/
    ├── loc/             (*.csv or *.po)
    └── thumbnail.png
```
Or packed as `my_mod.pck` (loaded via `ProjectSettings.load_resource_pack`).

**`mod.json`**
```json
{
  "id": "better_railguns",
  "name": "Better Railguns",
  "version": "1.2.0",
  "game_version": ">=1.0.0 <2.0.0",
  "authors": ["Toby"],
  "description": "Railguns hit harder, overheat more.",
  "dependencies": [{ "id": "core", "version": ">=1.0.0" }],
  "load_after": [],
  "load_before": [],
  "affects_sim": true,
  "has_scripts": false,
  "entry_scripts": []
}
```

---

## C11. Asset Conventions (Blender pipeline contract)

| Rule | Value |
|---|---|
| Format | glTF 2.0 binary (`.glb`) |
| Units | 1 Godot unit = 10 m |
| Axes | Godot forward = −Z; export with +Y up |
| Origin | Centre of mass; ships sit on origin |
| Hardpoints | Empties named `HP_<W|D|U|C|H>_<S|M|L>_<NN>` e.g. `HP_W_M_01` (must match `SlotDef.hardpoint`) |
| Other markers | `ENGINE_NN` (thruster FX), `BRIDGE`, `DOCK`, `LIGHT_NN` |
| LODs | Meshes suffixed `_LOD0`, `_LOD1`, `_LOD2` |
| Materials | Low-poly flat/vertex-colour; faction colour via material slot named `FACTION` (tinted at runtime) |
| Triangle budget | Corvette ≤ 800 · Cruiser ≤ 2,500 · Battleship ≤ 6,000 · Station ≤ 5,000 (LOD0) |
| Naming | `<species>_<class>_mk<N>.glb`, turrets `<component_id>.glb` |

The validator (C6) opens each hull `.glb` and checks every `SlotDef.hardpoint` exists.

---

## C12. Saves

```json
{
  "save_format": 1,
  "game_version": "1.0.0",
  "content_hash": "…",
  "mods": [{ "id": "core", "version": "1.0.0" }, …],
  "settings": { … match settings … },
  "match_seed": 123456789,
  "tick": 88213,
  "rng_states": { "combat": …, "events": …, "ai": …, "galaxy": … },
  "state": { … entities by string ID … },
  "mod_state": { "my_mod": { … } },
  "command_log_tail": [ … last N commands, for desync debugging … ]
}
```
- Written with `FileAccess` + deflate compression; autosave on month tick.
- **Migrations:** `save_format` bumps ship with a migration function chain.
- Loading with different mods: missing `affects_sim` mods block load with a clear list; extra cosmetic mods are fine.

---

## C13. Localisation

- All text via keys (`name_key`, `desc_key`, etc.) in `loc/<lang>.csv` (Godot TranslationServer).
- Mods can add keys or override core keys.
- Generated battle "key moments" use templated keys with parameters (`{ship}`, `{enemy}`).

---

## C14. Tooling

| Tool | Purpose |
|---|---|
| `tools/validate_content.gd` | Run C6 validation headless; CI for core and mods |
| `tools/mod_determinism_test.gd` | Two identical runs + checksum diff |
| `tools/export_schemas.gd` | Emits JSON Schema files for every Def (editor autocompletion for modders) |
| `tools/def_docs.gd` | Generates Markdown docs of all Defs and modifier keys |
| `tools/blender/` | Headless generation scripts + hardpoint conventions (modder kit) |
