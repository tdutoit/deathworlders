class_name CmdColonise
extends Command
## core:cmd/colonise {"unit": colony ship ID, "planet": target planet ID} (Sub-spec B10, D2, D9)
## The ship flies there and settles; an unclaimed system is claimed (and its influence paid) now.

const TYPE := &"core:cmd/colonise"


func validate(state: MatchState) -> bool:
	var reason := Colonisation.check_colonise(state, player_id, p_int("unit"), p_int("planet"))
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	Colonisation.order(state, state.units.get_or(p_int("unit")), p_int("planet"))
