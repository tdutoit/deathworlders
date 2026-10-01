class_name TemplateDef
extends Def
## A planet template (Sub-spec D4): an ordered build list for a focus pair. A template with no foci is the
## Colony-stage default (D2: Farm + Mine). Governors build in order, skipping what the planet can't hold.

@export var primary: StringName  # focus ID, empty for the colony default
@export var secondary: StringName
@export var build_order: Array[StringName] = []  # building IDs


func category() -> String:
	return "template"


func schema() -> Dictionary:
	return {
		"primary": {"type": "id", "ref": "focus"},
		"secondary": {"type": "id", "ref": "focus"},
		"build_order": {"type": "id_list", "ref": "building"},
	}


func validate(_db: DefDatabase) -> Array[String]:
	var errors: Array[String] = []
	if (primary == &"") != (secondary == &""):
		errors.append("set both primary and secondary, or neither (colony default)")
	if build_order.is_empty():
		errors.append("build_order is empty")
	return errors
