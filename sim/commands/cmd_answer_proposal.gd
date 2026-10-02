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
		var reason := Treaties.check_propose(state, p.from, p.to, p.def_id)
		if reason != "":
			return reject(reason)
	return true


func apply(state: MatchState) -> void:
	var p: Proposal = state.proposals.get_or(p_int("proposal"))
	state.proposals.erase(p.id)
	if p_int("accept") == 1:
		Treaties.sign(state, p.from, p.to, p.def_id)
	else:
		Treaties.refuse(state, p.from, p.to, p.def_id)
		var r := Treaties.rules(state)
		Relations.add_event(state, p.from, p.to, "denied", int(r.event_cap.get(&"denied", 0)))
