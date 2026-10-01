class_name CmdDebugSpawnScout
extends Command
## core:cmd/debug_spawn_scout {"system": id}: spawns a scout owned by the issuing player (debug/M1).

const TYPE := &"core:cmd/debug_spawn_scout"
const SCOUT_SPEED := 500  # milli-lane-units/hour: ~2.5 days per 30-unit lane; hull data later


func validate(state: MatchState) -> bool:
	if state.galaxy.system(p_int("system")) == null:
		return reject("unknown system %d" % p_int("system"))
	if state.empires.get_or(player_id) == null:
		return reject("unknown player %d" % player_id)
	return true


func apply(state: MatchState) -> void:
	var u := Unit.new()
	u.id = state.alloc_id()
	u.owner = player_id
	u.kind = "scout"
	u.system_id = p_int("system")
	u.speed = SCOUT_SPEED
	state.units.put(u.id, u)
