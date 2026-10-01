class_name CmdDeleteDesign
extends Command
## core:cmd/delete_design {"design": own design ID}. Ships built or queued from it keep their parts.

const TYPE := &"core:cmd/delete_design"


func validate(state: MatchState) -> bool:
	if Designs.owned(state, player_id, p_int("design")) == null:
		return reject("design %d is not yours" % p_int("design"))
	return true


func apply(state: MatchState) -> void:
	state.designs.erase(p_int("design"))
