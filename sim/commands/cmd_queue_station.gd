class_name CmdQueueStation
extends Command
## core:cmd/queue_station {"planet": id of the body to orbit, "station": tier-1 station Def ID}

const TYPE := &"core:cmd/queue_station"


func validate(state: MatchState) -> bool:
	var reason := BuildRules.check_station(state, player_id, p_int("planet"), str(payload.get("station", "")))
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	Builder.place_station(state, player_id, p_int("planet"), str(payload["station"]))
