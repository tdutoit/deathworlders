class_name CmdUpgradeStation
extends Command
## core:cmd/upgrade_station {"station": id}

const TYPE := &"core:cmd/upgrade_station"


func validate(state: MatchState) -> bool:
	var reason := BuildRules.check_upgrade(state, player_id, p_int("station"))
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	Builder.start_upgrade(state, state.station(p_int("station")))
