class_name CmdCancelConstruction
extends Command
## core:cmd/cancel_construction {"planet": id, "index": queue position} or {"station": id}

const TYPE := &"core:cmd/cancel_construction"


func validate(state: MatchState) -> bool:
	if payload.has("station"):
		var s := state.station(p_int("station"))
		if s == null or s.owner != player_id or s.build == null:
			return reject("nothing to cancel at station %d" % p_int("station"))
		return true
	var c := state.colony(p_int("planet"))
	if c == null or c.owner != player_id:
		return reject("planet %d is not your colony" % p_int("planet"))
	if p_int("index", -1) < 0 or p_int("index") >= c.queue.size():
		return reject("no queued item %d" % p_int("index", -1))
	return true


func apply(state: MatchState) -> void:
	if payload.has("station"):
		Builder.cancel(state, null, state.station(p_int("station")), 0)
	else:
		Builder.cancel(state, state.colony(p_int("planet")), null, p_int("index"))
