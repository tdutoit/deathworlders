class_name RouteRules
extends RefCounted
## Checks for manual routes (Sub-spec B8). Each returns a readable reason, or "" when allowed.


static func check_fields(state: MatchState, empire_id: int, source: int, dest: int, resource: String, amount: int, priority: int) -> String:
	if Holders.owner(state, source) != empire_id:
		return "source %d is not your colony or station" % source
	if Holders.owner(state, dest) != empire_id:
		return "destination %d is not your colony or station" % dest
	if source == dest:
		return "source and destination are the same"
	var res := state.defs.get_def(StringName(resource)) as ResourceDef
	if res == null or not res.physical:
		return "'%s' is not a physical resource" % resource
	if amount < 1 or amount > 100000:
		return "amount per trip must be 1-100000"
	if priority < 1 or priority > 3:
		return "priority must be 1 (Low), 2 (Normal) or 3 (Critical)"
	return ""


static func own_route(state: MatchState, empire_id: int, route_id: int) -> Route:
	var r: Route = state.routes.get_or(route_id)
	return r if r != null and r.owner == empire_id else null


## Freighters assigned to a route, in ID order.
static func freighters_on(state: MatchState, route_id: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for uid: int in state.units:
		var u: Unit = state.units.get_or(uid)
		if u.route == route_id:
			out.append(u)
	return out
