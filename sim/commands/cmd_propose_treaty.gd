class_name CmdProposeTreaty
extends Command
## core:cmd/propose_treaty {"to": empire ID, "treaty": treaty Def ID} (E4, E5). An AI empire answers at once by
## the E5 acceptance score (accepted: signed, the proposer pays the influence); a player gets a proposal to
## answer within proposal_days.

const TYPE := &"core:cmd/propose_treaty"


func validate(state: MatchState) -> bool:
	var reason := Treaties.check_propose(state, player_id, p_int("to"), str(payload.get("treaty", "")))
	if reason == "" and _pending(state) != null:
		reason = "already proposed"
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	var to := p_int("to")
	var def_id := str(payload["treaty"])
	if Autopilot.is_ai(state, to):
		if Treaties.accepts(state, player_id, to, def_id):
			Treaties.sign(state, player_id, to, def_id)
		else:
			Treaties.refuse(state, player_id, to, def_id)
		return
	var p := Proposal.new()
	p.id = state.alloc_id()
	p.def_id = def_id
	p.from = player_id
	p.to = to
	p.tick = state.tick
	p.expires_tick = state.tick + Treaties.rules(state).proposal_days * Calendar.HOURS_PER_DAY
	state.proposals.put(p.id, p)


func _pending(state: MatchState) -> Proposal:
	for pid: int in state.proposals.ordered():
		var p: Proposal = state.proposals.get_or(pid)
		if p.from == player_id and p.to == p_int("to") and p.def_id == str(payload.get("treaty", "")):
			return p
	return null
