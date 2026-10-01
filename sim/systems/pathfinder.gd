class_name Pathfinder
extends RefCounted
## Shortest routes over hyperlanes by total lane length. Ties break on lower system ID, so the
## result is deterministic. O(V^2) Dijkstra: fine for a few hundred systems.


## System IDs to visit after `from`, ending with `to`; [] if from == to or unreachable.
static func route(galaxy: Galaxy, from: int, to: int) -> Array[int]:
	var none: Array[int] = []
	if from == to or galaxy.system(from) == null or galaxy.system(to) == null:
		return none
	var dist := {from: 0}
	var prev := {}
	var done := {}
	while true:
		var best := -1
		for id: int in IdMap.sort_keys(dist.keys()):
			if not done.has(id) and (best < 0 or dist[id] < dist[best]):
				best = id
		if best < 0:
			return none
		if best == to:
			break
		done[best] = true
		for lane_id in galaxy.system(best).lane_ids:
			var lane := galaxy.lane(lane_id)
			var next := lane.other_end(best)
			var d: int = dist[best] + lane.length
			if not dist.has(next) or d < dist[next] or (d == dist[next] and best < prev.get(next, best)):
				dist[next] = d
				prev[next] = best
	var path: Array[int] = []
	var at := to
	while at != from:
		path.push_front(at)
		at = prev[at]
	return path
