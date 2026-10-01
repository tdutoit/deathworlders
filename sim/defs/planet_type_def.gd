class_name PlanetTypeDef
extends Def
## A planet type (main spec 4.1). M1 fields only: generation weights and a map colour.

const SIZES: Array[String] = ["tiny", "small", "medium", "large", "huge"]
const ZONES: Array[String] = ["inner", "habitable", "outer"]

@export var color: String  # "#rrggbb", cosmetic
@export var orbital_only: bool  # gas giants: stations only, no surface colony
@export var size_weights: Dictionary = {}  # size -> weight
@export var zone_weights: Dictionary = {}  # orbit zone -> weight


func category() -> String:
	return "planet_type"


func schema() -> Dictionary:
	return {
		"color": {"type": "color", "required": true},
		"orbital_only": {"type": "bool"},
		"size_weights": {"type": "int_map", "keys": SIZES, "min": 0},
		"zone_weights": {"type": "int_map", "keys": ZONES, "min": 0},
	}


func validate(_db: DefDatabase) -> Array[String]:
	var errors: Array[String] = []
	if _sum(size_weights) <= 0:
		errors.append("size_weights must have at least one positive weight")
	if _sum(zone_weights) <= 0:
		errors.append("zone_weights must have at least one positive weight")
	return errors


static func _sum(weights: Dictionary) -> int:
	var total := 0
	for w: int in weights.values():
		total += w
	return total
