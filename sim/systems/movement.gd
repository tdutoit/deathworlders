class_name Movement
extends RefCounted
## Hour-tick unit movement along hyperlanes (M1 WP5). Units are processed in ID order.
## Progress and speed are in milli-lane-units so slow units (freighters ~230/hour) keep precision.

const MILLI := 1000


static func tick(state: MatchState) -> void:
	for id: int in state.units.ordered():
		var u: Unit = state.units.get_or(id)
		if not u.is_moving():
			continue
		if u.fleet != StateIO.NONE:
			u.progress += Fleets.move_speed(state, u.fleet)  # the fleet moves as one (its slowest ship, fuel)
		else:
			u.progress += u.speed if not u.out_of_fuel else FixedMath.floor_div(u.speed, 2)
		while u.is_moving():
			var lane := state.galaxy.lane_between(u.system_id, u.path[0])
			if lane == null:  # lane vanished; stop where we are
				u.path.clear()
				u.progress = 0
				break
			if u.progress < lane.length * MILLI:
				break
			u.progress -= lane.length * MILLI
			u.system_id = u.path.pop_front()
		if not u.is_moving():
			u.progress = 0
