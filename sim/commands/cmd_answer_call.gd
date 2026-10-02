class_name CmdAnswerCall
extends Command
## core:cmd/answer_call {"call": ID, "join": 0|1}, by the called empire (E3, E4): joining declares war on the
## caller's attacker (+trust); refusing costs trust.

const TYPE := &"core:cmd/answer_call"


func validate(state: MatchState) -> bool:
	var c: CallToArms = state.calls.get_or(p_int("call"))
	if c == null or c.to != player_id:
		return reject("no such call to you")
	if p_int("join") == 1:
		var reason := Treaties.check_war(state, player_id, c.enemy)
		if reason != "":
			return reject(reason)
	return true


func apply(state: MatchState) -> void:
	Treaties.answer_call(state, state.calls.get_or(p_int("call")), p_int("join") == 1)
