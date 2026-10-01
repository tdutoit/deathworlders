class_name PlanetSizeDef
extends Def
## A planet size (Sub-spec B2). IDs are core:planet_size/<size> for each PlanetTypeDef.SIZES entry.

@export var building_slots: int
@export var housing: int
@export var orbital_slots: int


func category() -> String:
	return "planet_size"


func schema() -> Dictionary:
	return {
		"building_slots": {"type": "int", "min": 0},
		"housing": {"type": "int", "min": 0},
		"orbital_slots": {"type": "int", "min": 0},
	}


static func id_for(size: String) -> StringName:
	return StringName("core:planet_size/" + size)
