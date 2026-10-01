class_name ViewMath
extends RefCounted
## Float helpers for views (never used by the sim). Map coordinates: sim (x, y) -> world (x, 0, y).


static func world(x: int, y: int) -> Vector3:
	return Vector3(x, 0.0, y)


## ID of the screen point nearest `target` within max_px, or 0. points: id -> Vector2 (screen).
static func nearest(points: Dictionary, target: Vector2, max_px: float) -> int:
	var best := 0
	var best_d := max_px * max_px
	for id: int in IdMap.sort_keys(points.keys()):
		var d := target.distance_squared_to(points[id])
		if d <= best_d:
			best_d = d
			best = id
	return best


## Where a unit is drawn: on its lane between ticks. frac (0..1) is the time since the last tick.
static func unit_point(state: MatchState, u: Unit, frac: float) -> Vector2:
	var here := state.galaxy.system(u.system_id)
	var a := Vector2(here.x, here.y)
	if not u.is_moving():
		return a
	var there := state.galaxy.system(u.path[0])
	var lane := state.galaxy.lane_between(u.system_id, u.path[0])
	if lane == null or lane.length <= 0:
		return a
	var t := clampf((u.progress + u.speed * frac) / (lane.length * 1000.0), 0.0, 1.0)
	return a.lerp(Vector2(there.x, there.y), t)


## Heading of a moving unit in radians (0 = +x), or 0 when idle.
static func unit_heading(state: MatchState, u: Unit) -> float:
	if not u.is_moving():
		return 0.0
	var a := state.galaxy.system(u.system_id)
	var b := state.galaxy.system(u.path[0])
	return atan2(b.y - a.y, b.x - a.x)
