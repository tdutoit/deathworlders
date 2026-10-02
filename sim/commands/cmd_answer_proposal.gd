class_name CmdAnswerProposal
extends Command
## core:cmd/answer_proposal {"proposal": ID, "accept": 0|1}, by the empire it was made to. Accepting signs it
## (if it can still be proposed); declining costs the proposer's opinion of you ("denied", E2).

const TYPE := &"core:cmd/answer_proposal"


func validate(state: MatchState) -> bool:
	var p: Proposal = state.proposals.get_or(p_int("proposal"))
	if p == null or p.to != player_id:
		return reject("no such proposal to you")
	if p_int("accept") == 1:
		var reason := Treaties.check_propose(state, p.from, p.to, p.def_id) if p.def_id != "" else ""
		if reason == "" and not p.items.is_empty():
			reason = Deals.check(state, p.from, p.to, p.items, p.def_id != "" and Treaties.def_of(state, p.def_id).has("trade"))
		if reason != "":
			return reject(reason)
	return true


func apply(state: MatchState) -> void:
	var p: Proposal = state.proposals.get_or(p_int("proposal"))
	state.proposals.erase(p.id)
	if p_int("accept") == 1:
		if p.def_id != "":
			Treaties.sign(state, p.from, p.to, p.def_id)
		if not p.items.is_empty():
			Deals.execute(state, p.from, p.to, p.items)
	else:
		if p.def_id != "":
			Treaties.refuse(state, p.from, p.to, p.def_id)
		var r := Treaties.rules(state)
		Relations.add_event(state, p.from, p.to, "denied", int(r.event_cap.get(&"denied", 0)))
