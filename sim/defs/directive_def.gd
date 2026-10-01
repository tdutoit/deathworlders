class_name DirectiveDef
extends Def
## A sector directive (Sub-spec D3): default focus pairs for newly Developed planets and build priorities.
## primary_foci[i] pairs with secondary_foci[i]. best_fit picks per planet by deposits and habitability.

@export var primary_foci: Array[StringName] = []
@export var secondary_foci: Array[StringName] = []
@export var best_fit: bool
@export var build_priority: Array[StringName] = []  # building IDs, most wanted first
@export var station_priority: Array[StringName] = []  # station IDs, most wanted first


func category() -> String:
	return "directive"


func schema() -> Dictionary:
	return {
		"primary_foci": {"type": "id_list", "ref": "focus"},
		"secondary_foci": {"type": "id_list", "ref": "focus"},
		"best_fit": {"type": "bool"},
		"build_priority": {"type": "id_list", "ref": "building"},
		"station_priority": {"type": "id_list", "ref": "station"},
	}


func validate(_db: DefDatabase) -> Array[String]:
	var errors: Array[String] = []
	if primary_foci.size() != secondary_foci.size():
		errors.append("primary_foci and secondary_foci must pair up (same length)")
	if primary_foci.is_empty() and not best_fit:
		errors.append("needs focus pairs or best_fit")
	return errors
