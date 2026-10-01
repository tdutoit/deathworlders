class_name CmdRenameFleet
extends Command
## core:cmd/rename_fleet {"fleet": ID, "name": text ("" = the default name)}

const TYPE := &"core:cmd/rename_fleet"


func validate(state: MatchState) -> bool:
	if FleetRules.owned(state, player_id, p_int("fleet")) == null:
		return reject("fleet %d is not yours" % p_int("fleet"))
	var reason := FleetRules.check_name(str(payload.get("name", "")))
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	(state.fleets.get_or(p_int("fleet")) as Fleet).name = str(payload.get("name", "")).strip_edges()
