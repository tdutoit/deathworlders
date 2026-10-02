class_name CmdMakePeace
extends Command
## core:cmd/make_peace {"empire": empire ID}: debug/dev white peace at once (the M3 toggle). Real peace goes
## through core:cmd/offer_peace (E7). Battles between the two end as a truce on their next round.

const TYPE := &"core:cmd/make_peace"


func validate(state: MatchState) -> bool:
	if not state.wars.has(Battles.war_key(player_id, p_int("empire"))):
		return reject("not at war with empire %d" % p_int("empire"))
	return true


func apply(state: MatchState) -> void:
	var w := Wars.war_of(state, player_id, p_int("empire"))
	if w != null:
		Wars.make_peace(state, w, player_id, [])
	else:
		state.wars.erase(Battles.war_key(player_id, p_int("empire")))
