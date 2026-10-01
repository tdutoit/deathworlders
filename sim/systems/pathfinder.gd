class_name Pathfinder
extends RefCounted
## Shortest routes over hyperlanes by total lane length (Dijkstra with a binary heap).
## The heap orders by (distance, system ID) and equal-length predecessors prefer the lower system ID,
## so the result never depends on Dictionary order.


## System IDs to visit after `from`, ending with `to`; [] if from == to or unreachable.
## avoid: optional {system: true} never passed through (B8 "avoid hostile systems").
static func route(galaxy: Galaxy, from: int, to: int, avoid: Dictionary = {}) -> Array[int]:
	var none: Array[int] = []
	if from == to or galaxy.system(from) == null or galaxy.system(to) == null:
		return none
	var dist := {from: 0}
	var prev := {}
	var done := {}
	var heap: Array = [[0, from]]  # [dist, id] min-heap
	while not heap.is_empty():
		var top: Array = _pop(heap)
		var at: int = top[1]
		if done.has(at):
			continue
		done[at] = true
		if at == to:
			break
		for lane_id in galaxy.system(at).lane_ids:
			var lane := galaxy.lane(lane_id)
			var next := lane.other_end(at)
			if done.has(next) or (avoid.has(next) and next != to):
				continue
			var d: int = top[0] + lane.length
			if not dist.has(next) or d < dist[next] or (d == dist[next] and at < prev[next]):
				dist[next] = d
				prev[next] = at
				_push(heap, [d, next])
	if not done.has(to):
		return none
	var path: Array[int] = []
	var step := to
	while step != from:
		path.push_front(step)
		step = prev[step]
	return path


static func _less(a: Array, b: Array) -> bool:
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])


static func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		@warning_ignore("integer_division")
		var parent := (i - 1) / 2
		if not _less(heap[i], heap[parent]):
			break
		var tmp: Array = heap[i]
		heap[i] = heap[parent]
		heap[parent] = tmp
		i = parent


static func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return top
	heap[0] = last
	var i := 0
	while true:
		var smallest := i
		for child in [2 * i + 1, 2 * i + 2]:
			if child < heap.size() and _less(heap[child], heap[smallest]):
				smallest = child
		if smallest == i:
			break
		var tmp: Array = heap[i]
		heap[i] = heap[smallest]
		heap[smallest] = tmp
		i = smallest
	return top
