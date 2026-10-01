class_name CmdDeclareWar
extends Command
## core:cmd/declare_war {"empire": empire ID}. M3 stub (no AI diplomacy, no war goals): unilateral, the two
## empires are at war at once. M4 replaces it with real diplomacy (Sub-spec E).

const TYPE := &"core:cmd/declare_war"


func validate(state: MatchState) -> bool:
	var other := p_int("empire")
	if state.empire(other) == null or other == player_id:
		return reject("empire %d is not another empire" % other)
	if state.wars.has(Battles.war_key(player_id, other)):
		return reject("already at war")
	return true


func apply(state: MatchState) -> void:
	state.wars[Battles.war_key(player_id, p_int("empire"))] = true
