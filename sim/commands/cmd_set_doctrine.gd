class_name CmdSetDoctrine
extends Command
## core:cmd/set_doctrine {"fleet": ID, and any of "range" (standoff/line/close/boarding), "target"
## (largest/weakest/carriers/escorts/missiles), "retreat" (0 never, 250, 500, 750 permille losses),
## "formation", "stance"} (main spec 7.6; formation and stance have no battle effect in M3).

const TYPE := &"core:cmd/set_doctrine"


func validate(state: MatchState) -> bool:
	if FleetRules.owned(state, player_id, p_int("fleet")) == null:
		return reject("fleet %d is not yours" % p_int("fleet"))
	var checks := {"range": Fleet.RANGES, "target": Fleet.TARGETS, "formation": Fleet.FORMATIONS, "stance": Fleet.STANCES}
	for key: String in checks:
		if payload.has(key) and not str(payload[key]) in checks[key]:
			return reject("%s must be one of %s" % [key, checks[key]])
	if payload.has("retreat") and not p_int("retreat") in Fleet.RETREATS:
		return reject("retreat must be one of %s" % [Fleet.RETREATS])
	return true


func apply(state: MatchState) -> void:
	var f: Fleet = state.fleets.get_or(p_int("fleet"))
	if payload.has("range"):
		f.range_pref = str(payload["range"])
	if payload.has("target"):
		f.target_priority = str(payload["target"])
	if payload.has("retreat"):
		f.retreat_at = p_int("retreat")
	if payload.has("formation"):
		f.formation = str(payload["formation"])
	if payload.has("stance"):
		f.stance = str(payload["stance"])
