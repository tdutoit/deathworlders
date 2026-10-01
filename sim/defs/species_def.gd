class_name SpeciesDef
extends Def
## A playable species. M1 stub (WP3): habitability, home template and colour only.

@export var color: String  # "#rrggbb" empire colour default, cosmetic
@export var habitability: Dictionary = {}  # planet_type id -> permille; missing = 0
@export var home_template: StringName  # "sol" = handcrafted Sol (main spec 4.1b); "standard" otherwise
@export var home_planet_type: StringName  # planet_type id of the homeworld


func category() -> String:
	return "species"


func schema() -> Dictionary:
	return {
		"color": {"type": "color", "required": true},
		"habitability": {"type": "int_map", "key_ref": "planet_type", "min": 0, "max": 2000},
		"home_template": {"type": "enum", "values": ["sol", "standard"], "required": true},
		"home_planet_type": {"type": "id", "ref": "planet_type", "required": true},
	}
