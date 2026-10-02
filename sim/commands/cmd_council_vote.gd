class_name CmdCouncilVote
extends Command
## core:cmd/council_vote {"proposal": ID, "vote": 1 | -1 | 0}: a member's vote for the next session (E9).

const TYPE := &"core:cmd/council_vote"


func validate(state: MatchState) -> bool:
	if not Councils.is_member(state, player_id):
		return reject("only members vote")
	if not state.council.proposals.any(func(p: Dictionary) -> bool: return int(p["id"]) == p_int("proposal")):
		return reject("no such proposal")
	if not p_int("vote") in [-1, 0, 1]:
		return reject("vote 1, -1 or 0")
	return true


func apply(state: MatchState) -> void:
	Councils.cast(state, player_id, p_int("proposal"), p_int("vote"))
