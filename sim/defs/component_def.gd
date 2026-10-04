class_name ComponentDef
extends Def
## A ship component (Sub-spec C5, A2): a weapon (S/M/L), a hangar wing, or a defence / utility / core
## module. Weapons carry the A1 weapon stats; modules carry their effects as SHIP-scope modifiers
## (e.g. Armour Plating: ship.armor +80). A component fits a slot of the same type and at least its size.

const SIZES: Array[String] = ["S", "M", "L"]

@export var slot_type: StringName  # weapon / defence / utility / core / hangar (SlotDef.SlotType, lowercase)
@export var slot_size: StringName = &"S"
@export var family: StringName  # weapon_family ID; weapons and hangar wings only
@export var damage: int  # per shot
@export var shots: int  # per round
@export var accuracy: Array[int] = []  # base hit permille at [Long, Medium, Close]
@export var penetration: int  # flat armour ignored
@export var tracking: int  # permille bonus vs evasion
@export var ammo_per_shot: int  # 0 = no ammunition
@export var cost: Dictionary = {}  # resource ID -> amount
@export var model: String  # turret / module model for the hardpoint (C11)
@export var requires_tech: Array[StringName] = []  # techs needed to fit it (M5); empty = free


func category() -> String:
	return "component"


func schema() -> Dictionary:
	return {
		"requires_tech": {"type": "id_list", "ref": "tech"},
		"slot_type": {"type": "enum", "values": Array(SlotDef.type_names()), "required": true},
		"slot_size": {"type": "enum", "values": SIZES, "required": true},
		"family": {"type": "id", "ref": "weapon_family"},
		"damage": {"type": "int", "min": 0},
		"shots": {"type": "int", "min": 0},
		"accuracy": {"type": "int_list", "min": 0, "max": 1000},
		"penetration": {"type": "int", "min": 0},
		"tracking": {"type": "int"},
		"ammo_per_shot": {"type": "int", "min": 0},
		"cost": {"type": "int_map", "key_ref": "resource", "min": 0},
		"model": {"type": "string"},
	}


func is_weapon() -> bool:
	return slot_type == &"weapon" or slot_type == &"hangar"


func validate(_db: DefDatabase) -> Array[String]:
	var errors: Array[String] = []
	if is_weapon():
		if family == &"" or damage <= 0 or shots <= 0 or accuracy.size() != 3:
			errors.append("weapons and hangar wings need a family, damage > 0, shots > 0 and 3 accuracy values [L, M, C]")
	elif family != &"" or damage != 0 or shots != 0:
		errors.append("only weapons and hangar wings have a family, damage or shots")
	return errors


## True if this component may sit in that hull slot: same type, slot at least as large.
func fits(slot: SlotDef) -> bool:
	return SlotDef.type_names()[slot.slot_type] == String(slot_type) and SIZES.find(String(slot_size)) <= slot.slot_size
