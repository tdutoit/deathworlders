class_name CmdClaimSystem
extends Command
## core:cmd/claim_system {"system": ID}: claim another empire's system (E7: influence 25 each). A claim is a
## casus belli (take claimed systems) and costs opinion both ways while it stands (E2 overlapping claims).

const TYPE := &"core:cmd/claim_system"


func validate(state: MatchState) -> bool:
	var sys := state.galaxy.system(p_int("system"))
	if sys == null or sys.owner == StateIO.NONE or sys.owner == player_id or state.empire(sys.owner) == null:
		return reject("only another empire's system can be claimed")
	if not Relations.has_contact(state, player_id, sys.owner):
		return reject("no contact with its owner")
	if Wars.has_claim(state, player_id, p_int("system")):
		return reject("already claimed")
	if int(state.empire(player_id).treasury.get("core:resource/influence", 0)) < Wars.rules(state).claim_influence * Stockpile.MILLI:
		return reject("needs %d influence" % Wars.rules(state).claim_influence)
	return true


func apply(state: MatchState) -> void:
	var e := state.empire(player_id)
	e.treasury["core:resource/influence"] = int(e.treasury["core:resource/influence"]) - Wars.rules(state).claim_influence * Stockpile.MILLI
	state.claims[Wars.claim_key(player_id, p_int("system"))] = state.tick
