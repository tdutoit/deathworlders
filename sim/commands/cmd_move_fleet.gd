class_name CmdMoveFleet
extends Command
## core:cmd/move_fleet {"fleet": ID, "to": system ID}. Routes along hyperlanes (shortest total length); a fleet
## already on a lane finishes that lane first. The fleet moves at its slowest ship's speed.

const TYPE := &"core:cmd/move_fleet"

var _route: Array[int] = []


func validate(state: MatchState) -> bool:
	var f := FleetRules.owned(state, player_id, p_int("fleet"))
	if f == null:
		return reject("fleet %d is not yours" % p_int("fleet"))
	var target := p_int("to")
	if state.galaxy.system(target) == null:
		return reject("unknown system %d" % target)
	var lead := Fleets.lead(state, f)
	for sid in f.ships():
		if not (state.units.get_or(sid) as Unit).refit.is_empty():
			return reject("fleet %d is refitting" % f.id)  # M5
	if Battles.in_battle(state, lead.id):
		return reject("fleet %d is in battle (doctrine decides retreat)" % f.id)
	var start := lead.path[0] if lead.is_moving() else lead.system_id
	var route := Pathfinder.route(state.galaxy, start, target)
	if route.is_empty() and start != target:
		return reject("no route from %d to %d" % [start, target])
	_route = route
	if lead.is_moving():
		_route.push_front(lead.path[0])
	return true


func apply(state: MatchState) -> void:
	Fleets.set_route(state, state.fleets.get_or(p_int("fleet")), _route)
