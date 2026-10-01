class_name HullDef
extends Def
## A ship hull (Sub-spec C5). M1 stub for the Blender pipeline proof (WP12): stats from Sub-spec A2,
## cost/build days from B10, a fixed slot layout and the model whose hardpoints the validator checks.

static var _hardpoint_re := RegEx.create_from_string("^HP_[WDUCH]_[SML]_\\d{2}$")

@export var species: StringName  # species ID
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


func category() -> String:
	return "hull"


func schema() -> Dictionary:
	return {
		"species": {"type": "id", "ref": "species", "required": true},
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
	}


func validate(_db: DefDatabase) -> Array[String]:
	var errors: Array[String] = []
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
