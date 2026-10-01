class_name CmdApproveSuggestion
extends Command
## core:cmd/approve_suggestion {"planet": id}: queues the governor's suggestion on an Assisted planet (D3).

const TYPE := &"core:cmd/approve_suggestion"


func validate(state: MatchState) -> bool:
	var c := state.colony(p_int("planet"))
	if c == null or c.owner != player_id:
		return reject("planet %d is not your colony" % p_int("planet"))
	if c.suggestion == "":
		return reject("no suggestion to approve")
	var reason := BuildRules.check_building(state, player_id, c.id, c.suggestion)
	return reject(reason) if reason != "" else true


func apply(state: MatchState) -> void:
	var c := state.colony(p_int("planet"))
	Builder.queue_building(state, c, c.suggestion)
	c.suggestion = ""
