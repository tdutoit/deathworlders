class_name CmdQueueBuilding
extends Command
## core:cmd/queue_building {"planet": id, "building": building Def ID}

const TYPE := &"core:cmd/queue_building"


func validate(state: MatchState) -> bool:
	var reason := BuildRules.check_building(state, player_id, p_int("planet"), str(payload.get("building", "")))
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	Builder.queue_building(state, state.colony(p_int("planet")), str(payload["building"]))
