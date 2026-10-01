class_name CmdMakePeace
extends Command
## core:cmd/make_peace {"empire": empire ID}. M3 stub: unilateral. Battles between the two end as a truce on
## their next round.

const TYPE := &"core:cmd/make_peace"


func validate(state: MatchState) -> bool:
	if not state.wars.has(Battles.war_key(player_id, p_int("empire"))):
		return reject("not at war with empire %d" % p_int("empire"))
	return true


func apply(state: MatchState) -> void:
	state.wars.erase(Battles.war_key(player_id, p_int("empire")))
