class_name CmdSetAgentMission
extends Command
## core:cmd/set_agent_mission {"agent": ID, "mission": Espionage.MISSIONS} (M5 WP9). The agent stays in place.

const TYPE := &"core:cmd/set_agent_mission"


func validate(state: MatchState) -> bool:
	var a: Agent = state.agents.get_or(p_int("agent"))
	if a == null or a.owner != player_id:
		return reject("agent %d is not yours" % p_int("agent"))
	if not str(payload.get("mission", "")) in Espionage.MISSIONS:
		return reject("unknown mission")
	return true


func apply(state: MatchState) -> void:
	(state.agents.get_or(p_int("agent")) as Agent).mission = str(payload["mission"])
