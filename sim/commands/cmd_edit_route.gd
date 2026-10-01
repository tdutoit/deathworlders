class_name CmdEditRoute
extends Command
## core:cmd/edit_route {"route": id, optional "resource", "amount", "priority"}

const TYPE := &"core:cmd/edit_route"


func validate(state: MatchState) -> bool:
	var r := RouteRules.own_route(state, player_id, p_int("route"))
	if r == null:
		return reject("route %d is not yours" % p_int("route"))
	var reason := RouteRules.check_fields(state, player_id, r.source, r.dest, str(payload.get("resource", r.resource)),
			p_int("amount", r.amount), p_int("priority", r.priority))
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	var r: Route = state.routes.get_or(p_int("route"))
	r.resource = str(payload.get("resource", r.resource))
	r.amount = p_int("amount", r.amount)
	r.priority = p_int("priority", r.priority)
