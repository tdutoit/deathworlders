class_name CmdDeleteRoute
extends Command
## core:cmd/delete_route {"route": id}. Its freighters finish what they're doing and fly home.

const TYPE := &"core:cmd/delete_route"


func validate(state: MatchState) -> bool:
	return true if RouteRules.own_route(state, player_id, p_int("route")) != null else reject("route %d is not yours" % p_int("route"))


func apply(state: MatchState) -> void:
	for u in RouteRules.freighters_on(state, p_int("route")):
		u.route = StateIO.NONE
		if u.wait_hours == 0 and not u.is_moving():
			u.phase = "home"
	state.routes.erase(p_int("route"))
