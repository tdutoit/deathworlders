class_name CmdMoveConstruction
extends Command
## core:cmd/move_construction {"planet": id, "index": queue position, "to": new position} (colony building
## queue) or {"station": shipyard ID, "ship_index": queue position, "to": new position} (shipyard queue)
## (M4 WP15, F4). Only the front item is worked on; a moved item keeps its progress and paid materials.

const TYPE := &"core:cmd/move_construction"


func validate(state: MatchState) -> bool:
	var queue := _queue(state)
	if queue == null:
		return reject("no queue of yours there")
	var i := p_int("ship_index" if payload.has("ship_index") else "index", -1)
	var to := p_int("to", -1)
	if i < 0 or i >= queue.size() or to < 0 or to >= queue.size():
		return reject("queue positions %d -> %d out of range" % [i, to])
	return true


func apply(state: MatchState) -> void:
	var queue := _queue(state)
	var i := p_int("ship_index" if payload.has("ship_index") else "index")
	var item: Construction = queue.pop_at(i)
	queue.insert(p_int("to"), item)


func _queue(state: MatchState) -> Array[Construction]:
	if payload.has("ship_index"):
		var y := state.station(p_int("station"))
		return y.ship_queue if y != null and y.owner == player_id else null
	var c := state.colony(p_int("planet"))
	return c.queue if c != null and c.owner == player_id else null
