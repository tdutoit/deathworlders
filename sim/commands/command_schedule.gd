class_name CommandSchedule
extends RefCounted
## Lockstep input buffer (main spec 18.2): commands stamped for exec_tick = tick + delay, released
## in (exec_tick, player_id, seq) order. Not part of MatchState: it holds inputs, not state.

const DELAY := 2  # hour ticks between submission and execution

var _pending: Array[Command] = []
var _next_seq := 0


func size() -> int:
	return _pending.size()


## Stamps and queues cmd. Immediate commands (pause/speed) run at the current tick boundary.
func submit(cmd: Command, current_tick: int) -> void:
	cmd.exec_tick = current_tick + (0 if cmd.is_immediate() else DELAY)
	cmd.seq = _next_seq
	_next_seq += 1
	_pending.append(cmd)
	_pending.sort_custom(_before)


## Removes and returns every command with exec_tick <= tick, in execution order.
func take_due(tick: int) -> Array[Command]:
	var due: Array[Command] = []
	while not _pending.is_empty() and _pending[0].exec_tick <= tick:
		due.append(_pending.pop_front())
	return due


func clear() -> void:
	_pending.clear()


## Pending commands in execution order (for saves), and their restore.
func to_array() -> Array:
	var out := []
	for cmd in _pending:
		out.append(cmd.to_dict())
	return out


func restore(items: Array) -> void:
	_pending.clear()
	_next_seq = 0
	for d: Dictionary in items:
		var cmd := CommandRegistry.from_dict(d)
		_pending.append(cmd)
		_next_seq = maxi(_next_seq, cmd.seq + 1)
	_pending.sort_custom(_before)


static func _before(a: Command, b: Command) -> bool:
	if a.exec_tick != b.exec_tick:
		return a.exec_tick < b.exec_tick
	if a.player_id != b.player_id:
		return a.player_id < b.player_id
	return a.seq < b.seq
