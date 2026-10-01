class_name CmdAssignFreighter
extends Command
## core:cmd/assign_freighter {"unit": freighter ID, "route": route ID, or 0 to unassign}
## Only berthed freighters work (B6: freighters without a berth sit idle).

const TYPE := &"core:cmd/assign_freighter"


func validate(state: MatchState) -> bool:
	var u: Unit = state.units.get_or(p_int("unit"))
	if u == null or u.owner != player_id or u.kind != "freighter":
		return reject("unit %d is not your freighter" % p_int("unit"))
	if u.home == StateIO.NONE:
		return reject("freighter %d has no berth" % u.id)
	if p_int("route") != StateIO.NONE and RouteRules.own_route(state, player_id, p_int("route")) == null:
		return reject("route %d is not yours" % p_int("route"))
	return true


func apply(state: MatchState) -> void:
	var u: Unit = state.units.get_or(p_int("unit"))
	u.route = p_int("route")
	if u.wait_hours == 0 and not u.is_moving():
		u.phase = "to_source" if u.route != StateIO.NONE else "home"
