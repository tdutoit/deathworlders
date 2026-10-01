class_name CmdSetPatrol
extends Command
## core:cmd/set_patrol {"fleet": ID, "systems": [system IDs] ([] = end the patrol)} (main spec 6.6).
## The fleet cycles through the systems, staying combat_rules.patrol_wait_hours in each; every listed own
## system gets combat_rules.patrol_security (D9) while the patrol is set.

const TYPE := &"core:cmd/set_patrol"
const MAX_SYSTEMS := 8


func validate(state: MatchState) -> bool:
	if FleetRules.owned(state, player_id, p_int("fleet")) == null:
		return reject("fleet %d is not yours" % p_int("fleet"))
	var systems: Variant = payload.get("systems", [])
	if not systems is Array or (systems as Array).size() > MAX_SYSTEMS:
		return reject("a patrol lists at most %d systems" % MAX_SYSTEMS)
	for v: Variant in systems:
		if state.galaxy.system(int(v)) == null:
			return reject("unknown system %s" % str(v))
	return true


func apply(state: MatchState) -> void:
	var f: Fleet = state.fleets.get_or(p_int("fleet"))
	f.patrol = StateIO.ints(payload.get("systems", []))
	f.mission = "patrol" if not f.patrol.is_empty() else ""
	f.escort_hub = StateIO.NONE
	f.patrol_index = 0
	f.patrol_wait = 0
