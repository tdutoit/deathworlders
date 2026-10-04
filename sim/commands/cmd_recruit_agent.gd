class_name CmdRecruitAgent
extends Command
## core:cmd/recruit_agent {"target": empire ID, "mission": Espionage.MISSIONS} (main spec 12; M5 WP9).

const TYPE := &"core:cmd/recruit_agent"


func validate(state: MatchState) -> bool:
	var why := Espionage.check_recruit(state, player_id, p_int("target", -1), str(payload.get("mission", "")))
	return reject(why) if why != "" else true


func apply(state: MatchState) -> void:
	Espionage.recruit(state, player_id, p_int("target"), str(payload["mission"]))
