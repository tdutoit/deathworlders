class_name ResourceDef
extends Def
## A resource (Sub-spec B1). Physical resources live in local stockpiles; the rest are global pools.

@export var physical: bool
@export var base_value: int  # milli-credits per unit (Fuel 1.5 credits = 1500)
@export var stockpile_default_cap: int  # whole units per planet stockpile; 0 = uncapped (B5)


func category() -> String:
	return "resource"


func schema() -> Dictionary:
	return {
		"physical": {"type": "bool"},
		"base_value": {"type": "int", "min": 0},
		"stockpile_default_cap": {"type": "int", "min": 0},
	}
