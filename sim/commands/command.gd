class_name Command
extends RefCounted
## Base of every player/AI action (Sub-spec C7). The only way to change sim state.
## Logs and the network carry type_id + player_id + payload only; payload holds ints, Strings and
## arrays of those.

var type_id: StringName  # "core:cmd/move_unit"
var player_id: int  # M1: the issuing empire's ID
var exec_tick: int  # stamped by the lockstep scheduler
var seq: int  # submission order, breaks ties at the same exec_tick
var payload: Dictionary = {}
var error := ""  # why validate() rejected it


## Legality check against the state at exec_tick. Set `error` and return false to reject.
func validate(_state: MatchState) -> bool:
	return true


## The ONLY place state changes. Called only after validate() returned true.
func apply(_state: MatchState) -> void:
	pass


## Pause and speed commands run at the next tick boundary (delay 0), even while paused.
func is_immediate() -> bool:
	return false


func reject(reason: String) -> bool:
	error = reason
	return false


func p_int(key: String, default: int = 0) -> int:
	return int(payload.get(key, default))


func to_dict() -> Dictionary:
	return {"type_id": String(type_id), "player": player_id, "exec_tick": exec_tick, "seq": seq, "payload": payload.duplicate(true)}
