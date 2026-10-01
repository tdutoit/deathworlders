class_name HullDef
extends Def
## A ship hull (Sub-spec C5): combat stats (A2), cost and build days (B10), a fixed slot layout and the model
## whose hardpoints the validator checks. M2 adds civilian roles: freighters (B6) and colony ships (B10);
## M3 the combat fields (A1: size, crew, point defence, shield regen), defensive platforms and pirate raiders.

const ROLES: Array[String] = ["warship", "freighter", "colony", "scout", "platform", "raider"]
const SIZES: Array[String] = ["S", "M", "L", "XL"]  # A1 size (targeting, boarding, B12 fuel)
const YARD_SIZES: Array[String] = ["S", "M", "L"]  # B10: S up to destroyers, M up to battlecruisers/carriers, L all

static var _hardpoint_re := RegEx.create_from_string("^HP_[WDUCH]_[SML]_\\d{2}$")

@export var role: StringName = &"warship"
@export var species: StringName  # species ID; empty = any species can build it
@export var hull_class: StringName  # "corvette"
@export var mark: int = 1
@export var hull: int
@export var armor: int
@export var shield: int
@export var evasion: int
@export var speed: int
@export var slots: Array[SlotDef] = []  # fixed layout (C5)
@export var cost: Dictionary = {}  # resource ID -> amount
@export var build_days: int
@export var model: String  # .glb path, mod-relative or res:// (C11)
@export var cargo_capacity: int  # freighters: units per trip (B6)
@export var lane_speed: int  # civilian travel speed, lane units per day (B6)
@export var upkeep: Dictionary = {}  # resource ID -> units per month
@export var pop_cost: int  # colony ships: pops taken from the building planet
@export var size: StringName = &"S"
@export var crew: int  # boarding defence (A11); 0 = combat_rules.crew_by_size for this size
@export var pd: int  # point-defence attempts per round before modules (A8)
@export var shield_regen: int  # permille of shield_max per round; 0 = combat_rules.shield_regen
@export var shipyard_size: StringName = &"S"  # smallest shipyard that can build it (B10)
@export var credit_upkeep_milli: int  # B10 credits per month in milli (fractional values); 0 = upkeep's credits


func category() -> String:
	return "hull"


func schema() -> Dictionary:
	return {
		"role": {"type": "enum", "values": ROLES, "required": true},
		"species": {"type": "id", "ref": "species"},
		"hull_class": {"type": "name", "required": true},
		"mark": {"type": "int", "min": 1},
		"hull": {"type": "int", "min": 1},
		"armor": {"type": "int", "min": 0},
		"shield": {"type": "int", "min": 0},
		"evasion": {"type": "int", "min": 0},
		"speed": {"type": "int", "min": 0},
		"slots": {"type": "slots"},
		"cost": {"type": "int_map", "key_ref": "resource", "min": 0},
		"build_days": {"type": "int", "min": 0},
		"model": {"type": "string"},
		"cargo_capacity": {"type": "int", "min": 0},
		"lane_speed": {"type": "int", "min": 0},
		"upkeep": {"type": "int_map", "key_ref": "resource", "min": 0},
		"pop_cost": {"type": "int", "min": 0},
		"size": {"type": "enum", "values": SIZES},
		"crew": {"type": "int", "min": 0},
		"pd": {"type": "int", "min": 0},
		"shield_regen": {"type": "int", "min": 0},
		"shipyard_size": {"type": "enum", "values": YARD_SIZES},
		"credit_upkeep_milli": {"type": "int", "min": 0},
	}


func validate(_db: DefDatabase) -> Array[String]:
	var errors: Array[String] = []
	if role == &"freighter" and (cargo_capacity <= 0 or lane_speed <= 0):
		errors.append("freighters need cargo_capacity > 0 and lane_speed > 0")
	if role == &"colony" and pop_cost <= 0:
		errors.append("colony ships need pop_cost > 0")
	var seen := {}
	for s in slots:
		var hp := String(s.hardpoint)
		if _hardpoint_re.search(hp) == null:
			errors.append("slot hardpoint '%s' must look like HP_W_S_01 (C11)" % hp)
		elif not hp.begins_with(s.expected_prefix() + "_"):
			errors.append("slot hardpoint '%s' does not match its slot (expected %s_NN)" % [hp, s.expected_prefix()])
		if seen.has(hp):
			errors.append("hardpoint '%s' used by two slots" % hp)
		seen[hp] = true
	return errors
