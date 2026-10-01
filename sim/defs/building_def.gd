class_name BuildingDef
extends Def
## A planet building (Sub-spec B3, B10): provides jobs, flat outputs and modifiers; occupies one slot.
## Extraction buildings need a deposit, and the deposit's richness caps how many a planet holds.

@export var jobs: Dictionary = {}  # job ID -> count
@export var outputs: Dictionary = {}  # resource ID -> units per month, no pops needed (capital income)
@export var cost: Dictionary = {}  # resource ID -> units (before pace)
@export var build_days: int  # before pace
@export var upkeep: Dictionary = {}  # resource ID -> units per month
@export var requires_focus: StringName  # focus ID that must be the planet's Primary
@export var requires_deposit: StringName  # resource ID of a required deposit
@export var requires_system_planet_type: StringName  # planet type that must exist in the system
@export var unique: bool  # at most one per planet
@export var buildable: bool = true  # false: placed by scenario/start only (capital)
@export var uses_slot: bool = true  # false: doesn't take a building slot (capital)


func category() -> String:
	return "building"


func schema() -> Dictionary:
	return {
		"jobs": {"type": "int_map", "key_ref": "job", "min": 1},
		"outputs": {"type": "int_map", "key_ref": "resource", "min": 0},
		"cost": {"type": "int_map", "key_ref": "resource", "min": 0},
		"build_days": {"type": "int", "min": 0},
		"upkeep": {"type": "int_map", "key_ref": "resource", "min": 0},
		"requires_focus": {"type": "id", "ref": "focus"},
		"requires_deposit": {"type": "id", "ref": "resource"},
		"requires_system_planet_type": {"type": "id", "ref": "planet_type"},
		"unique": {"type": "bool"},
		"buildable": {"type": "bool"},
		"uses_slot": {"type": "bool"},
	}
