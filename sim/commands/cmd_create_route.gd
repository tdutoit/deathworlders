class_name CmdCreateRoute
extends Command
## core:cmd/create_route {"source": holder, "dest": holder, "resource": ID, "amount": units/trip, "priority": 1-3}

const TYPE := &"core:cmd/create_route"


func validate(state: MatchState) -> bool:
	var reason := RouteRules.check_fields(state, player_id, p_int("source"), p_int("dest"), str(payload.get("resource", "")),
			p_int("amount"), p_int("priority", 2))
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	var r := Route.new()
	r.id = state.alloc_id()
	r.owner = player_id
	r.source = p_int("source")
	r.dest = p_int("dest")
	r.resource = str(payload["resource"])
	r.amount = p_int("amount")
	r.priority = p_int("priority", 2)
	state.routes.put(r.id, r)
