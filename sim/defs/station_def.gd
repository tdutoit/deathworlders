class_name StationDef
extends Def
## An orbital station tier (main spec 5, Sub-spec B5/B6/B10/B11/B12). One Def per tier; a tier names the
## next one in upgrades_to. Stations occupy a planet's orbital slot; placement limits the planet types.

const FUNCTIONS: Array[String] = ["outpost", "mining", "logistics", "shipyard", "depot", "defence", "sensor", "research"]  # sensor, research: M5
const SHIP_SIZES: Array[String] = ["S", "M", "L"]

@export var function: StringName
@export var tier: int = 1
@export var upgrades_to: StringName  # station ID of the next tier
@export var cost: Dictionary = {}  # before pace (upgrades: the cost of this tier's upgrade)
@export var build_days: int
@export var upkeep: Dictionary = {}  # resource ID -> units per month
@export var placement: Array[StringName] = []  # planet types it may orbit; empty = any
@export var requires_deposit: StringName  # resource ID the orbited body must have
@export var outputs: Dictionary = {}  # resource ID -> units per month (mining)
@export var stockpile_cap: int  # whole units per resource; 0 = no stockpile
@export var berths: int
@export var hub_range: int  # lanes a hub's freighters serve (B8)
@export var docks: int
@export var shipyard_size: StringName  # "S", "M" or "L"
@export var supply_range: int  # lanes (B12)
@export var sector_range: int  # lanes a sector anchored here reaches (D3: T2 3, T3 5; 0 = can't anchor)
@export var design: StringName  # defence stations: the design it fights with (a platform hull, M3)
@export var security: int  # D9: +10 for defensive platforms and listening posts (none in M2)
@export var buildable: bool = true  # false: placed by rules only (M4 Sanctuary planetary defences)
@export var requires_tech: Array[StringName] = []  # techs needed to build or upgrade to it (M5); empty = free
@export var sensor_range: int  # D12: lanes of sensor coverage around its system (listening posts 2/3/4; M5)
@export var sensor_strength: int  # D12: detects contacts whose signature minus stealth is at most this (M5)


func category() -> String:
	return "station"


func schema() -> Dictionary:
	return {
		"sensor_strength": {"type": "int", "min": 0},
		"sensor_range": {"type": "int", "min": 0},
		"requires_tech": {"type": "id_list", "ref": "tech"},
		"function": {"type": "enum", "values": FUNCTIONS, "required": true},
		"tier": {"type": "int", "min": 1, "max": 3},
		"upgrades_to": {"type": "id", "ref": "station"},
		"cost": {"type": "int_map", "key_ref": "resource", "min": 0},
		"build_days": {"type": "int", "min": 0},
		"upkeep": {"type": "int_map", "key_ref": "resource", "min": 0},
		"placement": {"type": "id_list", "ref": "planet_type"},
		"requires_deposit": {"type": "id", "ref": "resource"},
		"outputs": {"type": "int_map", "key_ref": "resource", "min": 0},
		"stockpile_cap": {"type": "int", "min": 0},
		"berths": {"type": "int", "min": 0},
		"hub_range": {"type": "int", "min": 0},
		"docks": {"type": "int", "min": 0},
		"shipyard_size": {"type": "enum", "values": SHIP_SIZES},
		"supply_range": {"type": "int", "min": 0},
		"sector_range": {"type": "int", "min": 0},
		"security": {"type": "int", "min": 0},
		"design": {"type": "id", "ref": "design"},
		"buildable": {"type": "bool"},
	}


func validate(db: DefDatabase) -> Array[String]:
	var errors: Array[String] = []
	if function == &"shipyard" and (docks <= 0 or shipyard_size == &""):
		errors.append("shipyards need docks > 0 and a shipyard_size")
	if function == &"defence":
		var d := db.get_def(design) as DesignDef
		if d == null or (db.get_def(d.hull) as HullDef) == null or (db.get_def(d.hull) as HullDef).role != &"platform":
			errors.append("defence stations need a design on a platform hull")
	if upgrades_to != &"":
		var next := db.get_def(upgrades_to) as StationDef
		if next != null and (next.function != function or next.tier != tier + 1):
			errors.append("upgrades_to must be the same function, one tier higher")
	return errors
