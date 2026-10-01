class_name CmdMoveUnit
extends Command
## core:cmd/move_unit {"unit": id, "to": system id}. Routes along hyperlanes (shortest total length).
## A unit already on a lane finishes that lane first, then follows the new route.

const TYPE := &"core:cmd/move_unit"

var _route: Array[int] = []


func validate(state: MatchState) -> bool:
	var unit: Unit = state.units.get_or(p_int("unit"))
	if unit == null:
		return reject("unknown unit %d" % p_int("unit"))
	if unit.owner != player_id:
		return reject("unit %d is not owned by player %d" % [unit.id, player_id])
	if unit.fleet != StateIO.NONE:
		return reject("unit %d moves with its fleet (move_fleet)" % unit.id)
	var target := p_int("to")
	if state.galaxy.system(target) == null:
		return reject("unknown system %d" % target)
	var start := unit.path[0] if unit.is_moving() else unit.system_id
	var route := Pathfinder.route(state.galaxy, start, target)
	if route.is_empty() and start != target:
		return reject("no route from %d to %d" % [start, target])
	_route = route
	if unit.is_moving():
		_route.push_front(unit.path[0])
	return true


func apply(state: MatchState) -> void:
	var unit: Unit = state.units.get_or(p_int("unit"))
	unit.path = _route.duplicate()
	if unit.path.is_empty():
		unit.progress = 0
