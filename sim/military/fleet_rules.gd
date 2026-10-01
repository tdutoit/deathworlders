class_name FleetRules
extends RefCounted
## Shared checks for the fleet commands.

const MAX_NAME := 40


static func owned(state: MatchState, eid: int, fleet_id: int) -> Fleet:
	var f: Fleet = state.fleets.get_or(fleet_id)
	return f if f != null and f.owner == eid else null


## "" if these are the empire's warships, all in one system and none moving.
static func check_ships(state: MatchState, eid: int, ships: Variant) -> String:
	if not ships is Array or (ships as Array).is_empty():
		return "no ships given"
	var system := StateIO.NONE
	var seen := {}
	for v: Variant in ships:
		var u: Unit = state.units.get_or(int(v))
		if u == null or u.owner != eid or u.kind != "warship":
			return "unit %s is not one of your warships" % str(v)
		if seen.has(u.id):
			return "unit %d listed twice" % u.id
		seen[u.id] = true
		if u.is_moving():
			return "unit %d is moving" % u.id
		if Battles.in_battle(state, u.id):
			return "unit %d is in battle" % u.id
		if system != StateIO.NONE and u.system_id != system:
			return "the ships must be in one system"
		system = u.system_id
	return ""


static func check_name(name: String) -> String:
	return "fleet names are at most %d characters" % MAX_NAME if name.strip_edges().length() > MAX_NAME else ""
