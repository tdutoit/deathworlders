class_name DesignDef
extends Def
## A ship design shipped as content (main spec 7.4, C5): a hull and one component per hull slot, in the
## hull's slot order ("" = empty slot). Used for species default designs, defensive platforms and pirates;
## player designs (M3 WP2) have the same shape and live in the match state.

@export var hull: StringName
@export var components: Array[StringName] = []


func category() -> String:
	return "design"


func schema() -> Dictionary:
	return {
		"hull": {"type": "id", "ref": "hull", "required": true},
		"components": {"type": "id_list", "ref": "component", "allow_empty": true},
	}


func validate(db: DefDatabase) -> Array[String]:
	return check_fit(db.get_def(hull) as HullDef, components, db)


## Errors for a hull + component list (shared with player designs): one entry per slot, each fitting it.
static func check_fit(h: HullDef, comps: Array, db: DefDatabase) -> Array[String]:
	var errors: Array[String] = []
	if h == null:
		return errors  # the reference check reports a missing hull
	if comps.size() != h.slots.size():
		errors.append("needs %d components (one per slot, \"\" for empty), got %d" % [h.slots.size(), comps.size()])
		return errors
	for i in comps.size():
		if StringName(comps[i]) == &"":
			continue
		var c := db.get_def(StringName(comps[i])) as ComponentDef
		if c != null and not c.fits(h.slots[i]):
			errors.append("slot %d (%s): %s doesn't fit" % [i, h.slots[i].hardpoint, comps[i]])
	return errors
