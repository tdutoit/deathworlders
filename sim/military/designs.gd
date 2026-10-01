class_name Designs
extends RefCounted
## Empire ship designs (main spec 7.4, C5): validation, saving, and the standard designs every empire
## starts with (its species' design Defs).

const MAX_NAME := 40


## "" if this empire may save a design with these parts, else the reason.
static func check(state: MatchState, eid: int, name: String, hull_id: String, components: Array) -> String:
	var e := state.empire(eid)
	if e == null:
		return "no such empire"
	if name.strip_edges() == "" or name.length() > MAX_NAME:
		return "a design needs a name of 1-%d characters" % MAX_NAME
	var h := state.defs.get_def(StringName(hull_id)) as HullDef
	if h == null:
		return "unknown hull %s" % hull_id
	if h.role != &"warship":
		return "%s is not a warship hull" % hull_id
	if h.species != &"" and String(h.species) != e.species:
		return "%s is a %s hull" % [hull_id, h.species]
	for cid: Variant in components:
		if not cid is String:
			return "component IDs must be strings"
		if cid != "" and not state.defs.get_def(StringName(cid)) is ComponentDef:
			return "unknown component %s" % cid
	var errors := DesignDef.check_fit(h, components, state.defs)
	return errors[0] if not errors.is_empty() else ""


## Saves a new design (design_id 0) or replaces one of the empire's own. Returns the design.
static func save(state: MatchState, eid: int, design_id: int, name: String, hull_id: String, components: Array) -> ShipDesign:
	var d: ShipDesign = state.designs.get_or(design_id) if design_id != 0 else null
	if d == null:
		d = ShipDesign.new()
		d.id = state.alloc_id()
		d.owner = eid
		state.designs.put(d.id, d)
	d.name = name.strip_edges()
	d.hull = hull_id
	d.components.assign(components)
	return d


## Gives an empire a copy of each standard design Def for its species (match start). The name is the
## Def's loc key; the UI translates it.
static func give_standard(state: MatchState, eid: int) -> void:
	var e := state.empire(eid)
	for def in state.defs.defs("design"):
		var dd: DesignDef = def
		var h := state.defs.get_def(dd.hull) as HullDef
		if h == null or h.role != &"warship" or String(h.species) != e.species:
			continue
		var d := save(state, eid, 0, dd.name_key, String(dd.hull), Array(dd.components).map(func(c: StringName) -> String: return String(c)))
		d.source = String(dd.id)


static func owned(state: MatchState, eid: int, design_id: int) -> ShipDesign:
	var d: ShipDesign = state.designs.get_or(design_id)
	return d if d != null and d.owner == eid else null
