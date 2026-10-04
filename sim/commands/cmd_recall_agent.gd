class_name CmdRecallAgent
extends Command
## core:cmd/recall_agent {"agent": ID} (M5 WP9): ends the agent (no refund).

const TYPE := &"core:cmd/recall_agent"


func validate(state: MatchState) -> bool:
	var a: Agent = state.agents.get_or(p_int("agent"))
	return reject("agent %d is not yours" % p_int("agent")) if a == null or a.owner != player_id else true


func apply(state: MatchState) -> void:
	state.agents.erase(p_int("agent"))
