class_name CmdRebaseFreighter
extends Command
## core:cmd/rebase_freighter {"unit": freighter ID, "hub": station or colony ID with a free berth}

const TYPE := &"core:cmd/rebase_freighter"


func validate(state: MatchState) -> bool:
	var reason := Shipyards.check_rebase(state, player_id, p_int("unit"), p_int("hub"))
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	(state.units.get_or(p_int("unit")) as Unit).home = p_int("hub")
