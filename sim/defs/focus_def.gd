class_name FocusDef
extends Def
## A planet focus (main spec 4.2, Sub-spec B4). Primary gets the full bonus and effects; Secondary
## gets half of both (B change log 2026-10-01).

@export var boosted_jobs: Array[StringName] = []
@export var bonus_permille: int = 500


func category() -> String:
	return "focus"


func schema() -> Dictionary:
	return {
		"boosted_jobs": {"type": "id_list", "ref": "job"},
		"bonus_permille": {"type": "int", "min": 0},
	}
