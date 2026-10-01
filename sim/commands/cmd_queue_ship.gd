class_name CmdQueueShip
extends Command
## core:cmd/queue_ship {"station": shipyard ID, "hull": hull Def ID} (civilian hulls in M2)

const TYPE := &"core:cmd/queue_ship"


func validate(state: MatchState) -> bool:
	var reason := Shipyards.check_ship(state, player_id, p_int("station"), str(payload.get("hull", "")))
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	Shipyards.queue_ship(state, state.station(p_int("station")), str(payload["hull"]))
