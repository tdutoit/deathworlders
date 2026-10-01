class_name CmdMoveSquadron
extends Command
## core:cmd/move_squadron {"fleet": ID, "task_force": index, "squadron": index, "to": task force index}
## Manual reorganisation (main spec 7.1); "to" = the task force count starts a new task force. Auto-grouping
## rebuilds the hierarchy when ships join or leave.

const TYPE := &"core:cmd/move_squadron"


func validate(state: MatchState) -> bool:
	var f := FleetRules.owned(state, player_id, p_int("fleet"))
	if f == null:
		return reject("fleet %d is not yours" % p_int("fleet"))
	var r := Fleets.rules(state)
	var tf := p_int("task_force", -1)
	var to := p_int("to", -1)
	if tf < 0 or tf >= f.task_forces.size() or p_int("squadron", -1) < 0 or p_int("squadron") >= (f.task_forces[tf] as Array).size():
		return reject("no such squadron")
	if to < 0 or to > f.task_forces.size() or to == tf:
		return reject("no such task force")
	if to == f.task_forces.size() and to >= r.fleet_task_forces:
		return reject("a fleet has at most %d task forces" % r.fleet_task_forces)
	if to < f.task_forces.size() and (f.task_forces[to] as Array).size() >= r.task_force_squadrons:
		return reject("that task force is full")
	return true


func apply(state: MatchState) -> void:
	var f: Fleet = state.fleets.get_or(p_int("fleet"))
	var sq: Array = (f.task_forces[p_int("task_force")] as Array).pop_at(p_int("squadron"))
	if p_int("to") == f.task_forces.size():
		f.task_forces.append([])
	(f.task_forces[p_int("to")] as Array).append(sq)
	f.task_forces = f.task_forces.filter(func(t: Array) -> bool: return not t.is_empty())
