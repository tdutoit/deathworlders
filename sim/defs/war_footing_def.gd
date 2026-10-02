class_name WarFootingDef
extends Def
## A war footing (Sub-spec D7; M4 WP7): Peace, Mobilised, Total War. Job output per resource (Workers' alloys,
## munitions, Clerks' credits, research), empire-wide stability, and war exhaustion: gains from losses scaled
## by `exhaustion_permille`, plus `monthly_exhaustion` milli-points a month (E7's +1/month at Total War).
## Species with `empire.total_war_exhaustion` (humans, Stubborn: 350) use that factor instead of
## `exhaustion_permille` and scale the monthly gain by it, wherever this footing has `total_war`.

@export var output: Dictionary = {}  # resource ID -> permille
@export var stability: int
@export var exhaustion_permille: int = 1000
@export var monthly_exhaustion: int  # milli-points a month
@export var total_war: bool
@export var order: int  # Peace 0, Mobilised 1, Total War 2 (UI and AI)


func category() -> String:
	return "war_footing"


func schema() -> Dictionary:
	return {
		"output": {"type": "int_map", "key_ref": "resource"},
		"stability": {"type": "int"},
		"exhaustion_permille": {"type": "int", "min": 0},
		"monthly_exhaustion": {"type": "int", "min": 0},
		"total_war": {"type": "bool"},
		"order": {"type": "int", "min": 0},
	}
