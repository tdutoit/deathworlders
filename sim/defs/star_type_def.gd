class_name StarTypeDef
extends Def
## A star type: how often it appears and how many planets it gets (M1 WP7 uses these).

@export var color: String  # "#rrggbb", cosmetic
@export var weight: int  # relative spawn weight
@export var planet_min: int
@export var planet_max: int


func category() -> String:
	return "star_type"


func schema() -> Dictionary:
	return {
		"color": {"type": "color", "required": true},
		"weight": {"type": "int", "min": 0},
		"planet_min": {"type": "int", "min": 0, "max": 8},
		"planet_max": {"type": "int", "min": 0, "max": 8},
	}


func validate(_db: DefDatabase) -> Array[String]:
	var errors: Array[String] = []
	if planet_min > planet_max:
		errors.append("planet_min (%d) is greater than planet_max (%d)" % [planet_min, planet_max])
	return errors
