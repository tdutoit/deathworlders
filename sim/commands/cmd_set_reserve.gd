class_name CmdSetReserve
extends Command
## core:cmd/set_reserve {"holder": id, "resource": ID, "units": n}: what auto-logistics leaves at the holder.
## units -1 goes back to the default (20% of the cap, B8).

const TYPE := &"core:cmd/set_reserve"


func validate(state: MatchState) -> bool:
	if Holders.owner(state, p_int("holder")) != player_id:
		return reject("holder %d is not your colony or station" % p_int("holder"))
	if not state.defs.get_def(StringName(str(payload.get("resource", "")))) is ResourceDef:
		return reject("unknown resource '%s'" % payload.get("resource", ""))
	if p_int("units", -2) < -1:
		return reject("units must be -1 (default) or more")
	return true


func apply(state: MatchState) -> void:
	var key := "%d:%s" % [p_int("holder"), str(payload["resource"])]
	if p_int("units") < 0:
		state.reserves.erase(key)
	else:
		state.reserves[key] = p_int("units")
