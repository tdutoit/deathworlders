class_name CmdReverseEngineer
extends Command
## core:cmd/reverse_engineer {"species": species ID, "tech": tech ID} (main spec 8.3; M5 WP8): spends that
## species' fragments on one of its techs (ReverseEngineering), which joins the research queue at half cost.

const TYPE := &"core:cmd/reverse_engineer"


func validate(state: MatchState) -> bool:
	var why := ReverseEngineering.check(state, player_id, str(payload.get("species", "")), str(payload.get("tech", "")))
	return reject(why) if why != "" else true


func apply(state: MatchState) -> void:
	ReverseEngineering.apply(state, player_id, str(payload["species"]), str(payload["tech"]))
