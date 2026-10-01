class_name CmdSetAutonomy
extends Command
## core:cmd/set_autonomy {"planet": id, "autonomy": "automated" | "assisted" | "manual"} (Sub-spec D3)

const TYPE := &"core:cmd/set_autonomy"
const MODES: Array[String] = ["automated", "assisted", "manual"]


func validate(state: MatchState) -> bool:
	var c := state.colony(p_int("planet"))
	if c == null or c.owner != player_id:
		return reject("planet %d is not your colony" % p_int("planet"))
	if not str(payload.get("autonomy", "")) in MODES:
		return reject("autonomy must be one of %s" % [MODES])
	return true


func apply(state: MatchState) -> void:
	var c := state.colony(p_int("planet"))
	c.autonomy = str(payload["autonomy"])
	if c.autonomy != "assisted":
		c.suggestion = ""
