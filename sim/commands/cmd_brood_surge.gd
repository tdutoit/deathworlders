class_name CmdBroodSurge
extends Command
## core:cmd/brood_surge {"colony": planet ID} (Krothi Brood Surge, M4 WP9): pops become a corvette.

const TYPE := &"core:cmd/brood_surge"


func validate(state: MatchState) -> bool:
	var reason := BroodSurgeMechanic.check(state, player_id, p_int("colony"))
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	BroodSurgeMechanic.surge(state, player_id, p_int("colony"))
