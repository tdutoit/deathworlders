class_name DifficultyDef
extends Def
## An AI difficulty level (Sub-spec E13; M4 WP12): every bonus is listed openly in match setup.
## Output bonus on the AI empire's job output; strategic actions a month (E12's top N).

@export var output_permille: int
@export var actions: int
@export var order: int
@export var intel_bonus: int  # E13: Admiral +1 intel level (M5)
@export var full_vision: bool  # E13: Deathworld sees everything (labelled cheat, M5)


func category() -> String:
	return "difficulty"


func schema() -> Dictionary:
	return {
		"output_permille": {"type": "int"},
		"actions": {"type": "int", "min": 1},
		"order": {"type": "int", "min": 0},
		"intel_bonus": {"type": "int", "min": 0, "max": 4},
		"full_vision": {"type": "bool"},
	}
