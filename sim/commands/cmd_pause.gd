class_name CmdPause
extends Command
## core:cmd/pause {"paused": 1 | 0}

const TYPE := &"core:cmd/pause"


func validate(_state: MatchState) -> bool:
	if not p_int("paused", -1) in [0, 1]:
		return reject("paused must be 0 or 1")
	return true


func apply(state: MatchState) -> void:
	state.paused = p_int("paused") == 1


func is_immediate() -> bool:
	return true
