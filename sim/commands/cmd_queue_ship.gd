class_name CmdQueueShip
extends Command
## core:cmd/queue_ship {"station": shipyard ID, "hull": hull Def ID} for civilian hulls (M2), or
## {"station", "design": own design ID} for warships (M3).

const TYPE := &"core:cmd/queue_ship"


func validate(state: MatchState) -> bool:
	var reason: String
	if payload.has("design"):
		reason = Shipyards.check_design_ship(state, player_id, p_int("station"), p_int("design"))
	else:
		reason = Shipyards.check_ship(state, player_id, p_int("station"), str(payload.get("hull", "")))
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	if payload.has("design"):
		Shipyards.queue_design(state, state.station(p_int("station")), p_int("design"))
	else:
		Shipyards.queue_ship(state, state.station(p_int("station")), str(payload["hull"]))
