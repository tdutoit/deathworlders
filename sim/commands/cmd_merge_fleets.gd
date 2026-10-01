class_name CmdMergeFleets
extends Command
## core:cmd/merge_fleets {"into": fleet ID, "from": fleet ID}: both own, idle, in the same system.

const TYPE := &"core:cmd/merge_fleets"


func validate(state: MatchState) -> bool:
	var into := FleetRules.owned(state, player_id, p_int("into"))
	var from := FleetRules.owned(state, player_id, p_int("from"))
	if into == null or from == null or into.id == from.id:
		return reject("merge needs two different fleets of yours")
	var reason := FleetRules.check_ships(state, player_id, into.ships() + from.ships())
	if reason == "" and not Fleets.fits(state, into.ships() + from.ships()):
		reason = "too many ships for one fleet"
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	var into: Fleet = state.fleets.get_or(p_int("into"))
	Fleets.add_ships(state, into, (state.fleets.get_or(p_int("from")) as Fleet).ships())
