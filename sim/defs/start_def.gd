class_name StartDef
extends Def
## A homeworld opening (Sub-spec B19): pops, buildings, foci, job caps, local stockpile and treasury.
## Applied to every empire's capital planet at match start (species-specific starts come with M4).

@export var pops: int
@export var buildings: Array[StringName] = []  # building IDs (may repeat)
@export var primary_focus: StringName
@export var secondary_focus: StringName
@export var job_caps: Dictionary = {}  # job ID -> max employed (B19's exact mix)
@export var stockpile: Dictionary = {}  # resource ID -> whole units on the capital
@export var treasury: Dictionary = {}  # global resource ID -> whole units (credits, research, influence)
@export var stage: StringName = &"core"


func category() -> String:
	return "start"


func schema() -> Dictionary:
	return {
		"pops": {"type": "int", "min": 1},
		"buildings": {"type": "id_list", "ref": "building"},
		"primary_focus": {"type": "id", "ref": "focus"},
		"secondary_focus": {"type": "id", "ref": "focus"},
		"job_caps": {"type": "int_map", "key_ref": "job", "min": 0},
		"stockpile": {"type": "int_map", "key_ref": "resource", "min": 0},
		"treasury": {"type": "int_map", "key_ref": "resource", "min": 0},
		"stage": {"type": "enum", "values": ["outpost", "colony", "developed", "core"]},
	}
