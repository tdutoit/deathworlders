class_name CmdCancelTreaty
extends Command
## core:cmd/cancel_treaty {"treaty": ID}, by either party. After the minimum duration it ends cleanly (or starts
## its notice); earlier, it is broken with the E3/E4 penalties.

const TYPE := &"core:cmd/cancel_treaty"


func validate(state: MatchState) -> bool:
	var t: Treaty = state.treaties.get_or(p_int("treaty"))
	if t == null or (t.a != player_id and t.b != player_id):
		return reject("not your treaty")
	return true


func apply(state: MatchState) -> void:
	Treaties.cancel(state, state.treaties.get_or(p_int("treaty")), player_id)
