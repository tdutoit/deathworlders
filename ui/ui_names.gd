class_name UiNames
extends RefCounted
## Display names for Defs, holders (colonies and stations) and owners, through loc keys.


static func def_name(id: String) -> String:
	var def := Database.defs.get_def(StringName(id)) if Database.defs else null
	return TranslationServer.translate(def.name_key) if def else id


## A colony shows its planet name; a station "Logistics Station T2 · Mars".
static func holder(state: MatchState, id: int) -> String:
	var c := state.colony(id)
	if c != null:
		return state.galaxy.planet(id).name
	var s := state.station(id)
	if s != null:
		return "%s · %s" % [def_name(s.def_id), state.galaxy.planet(s.planet_id).name]
	return "#%d" % id


static func owner(state: MatchState, eid: int) -> String:
	if eid == Pirates.PIRATES:
		return TranslationServer.translate("OWNER_PIRATES")
	var e := state.empire(eid)
	return def_name(e.species) if e else TranslationServer.translate("CTX_UNCLAIMED")


## Ten-cell fill bar ("▮▮▮▯▯▯▯▯▯▯"); never colour alone (F1).
static func bar(milli: int, cap_milli: int) -> String:
	if cap_milli <= 0:
		return ""
	var n := clampi(milli * 10 / cap_milli, 0, 10)
	return "▮".repeat(n) + "▯".repeat(10 - n)


static func priority(p: int) -> String:
	return "●".repeat(p) + "○".repeat(3 - p)
