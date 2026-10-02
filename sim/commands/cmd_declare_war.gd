class_name CmdDeclareWar
extends Command
## core:cmd/declare_war {"empire": empire ID, "casus_belli": "claim" | "retaliation" | "protectorate" |
## "containment" | "" (none)} (Sub-spec E7). Without a casus belli the war is allowed but costs Reputation and
## everyone's opinion, and allies aren't called. A non-aggression pact needs its notice to have run out.

const TYPE := &"core:cmd/declare_war"


func validate(state: MatchState) -> bool:
	var other := p_int("empire")
	if state.empire(other) == null or other == player_id:
		return reject("empire %d is not another empire" % other)
	if state.wars.has(Battles.war_key(player_id, other)):
		return reject("already at war")
	var treaty_reason := Treaties.check_war(state, player_id, other)
	if treaty_reason != "":
		return reject(treaty_reason)
	var cb := str(payload.get("casus_belli", ""))
	if cb != "" and not cb in Wars.casus_belli(state, player_id, other):
		return reject("no %s casus belli against empire %d" % [cb, other])
	return true


func apply(state: MatchState) -> void:
	Wars.declare(state, player_id, p_int("empire"), str(payload.get("casus_belli", "")))
