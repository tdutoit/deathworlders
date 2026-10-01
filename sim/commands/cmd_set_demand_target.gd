class_name CmdSetDemandTarget
extends Command
## core:cmd/set_demand_target {"holder": id, "resource": ID, "target": units, "priority": 1-3}
## Keeps a holder at or above the target via auto-logistics (B8). Target 0 removes the demand.

const TYPE := &"core:cmd/set_demand_target"


func validate(state: MatchState) -> bool:
	if Holders.owner(state, p_int("holder")) != player_id:
		return reject("holder %d is not your colony or station" % p_int("holder"))
	var res := state.defs.get_def(StringName(str(payload.get("resource", "")))) as ResourceDef
	if res == null or not res.physical:
		return reject("'%s' is not a physical resource" % payload.get("resource", ""))
	if p_int("target", -1) < 0:
		return reject("target must be 0 or more")
	if p_int("priority", 2) < 1 or p_int("priority", 2) > 3:
		return reject("priority must be 1-3")
	return true


func apply(state: MatchState) -> void:
	var existing := find(state, player_id, p_int("holder"), str(payload["resource"]))
	if p_int("target") == 0:
		if existing != null:
			state.demands.erase(existing.id)
		return
	if existing == null:
		existing = Demand.new()
		existing.id = state.alloc_id()
		existing.owner = player_id
		existing.holder = p_int("holder")
		existing.resource = str(payload["resource"])
		state.demands.put(existing.id, existing)
	existing.target = p_int("target")
	existing.priority = p_int("priority", 2)


static func find(state: MatchState, owner: int, holder: int, res: String) -> Demand:
	for did: int in state.demands:
		var d: Demand = state.demands.get_or(did)
		if d.owner == owner and d.holder == holder and d.resource == res:
			return d
	return null
