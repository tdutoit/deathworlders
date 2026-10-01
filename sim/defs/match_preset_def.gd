class_name MatchPresetDef
extends Def
## A match setting preset (main spec 17): a galaxy size or a pace.

@export var kind: StringName  # "galaxy_size" or "pace"
@export var sort_order: int  # display order in match setup
# galaxy_size
@export var target_systems: int
@export var cluster_count: int
# pace (Sub-spec B0): scales costs and build times
@export var pace_permille: int


func category() -> String:
	return "match_preset"


func schema() -> Dictionary:
	return {
		"kind": {"type": "enum", "values": ["galaxy_size", "pace"], "required": true},
		"sort_order": {"type": "int"},
		"target_systems": {"type": "int", "min": 0},
		"cluster_count": {"type": "int", "min": 0},
		"pace_permille": {"type": "int", "min": 0},
	}


func validate(_db: DefDatabase) -> Array[String]:
	var errors: Array[String] = []
	if kind == &"galaxy_size":
		if target_systems <= 0 or cluster_count <= 0:
			errors.append("galaxy_size presets need target_systems > 0 and cluster_count > 0")
	elif kind == &"pace" and pace_permille <= 0:
		errors.append("pace presets need pace_permille > 0")
	return errors
