class_name CmdSetResearch
extends Command
## core:cmd/set_research {"queue": [tech IDs in order]} (C7 `set_research`, M5 WP2): replaces the empire's
## research queue. Every entry must be a tech the empire may still research this match (not researched, its
## species, not locked by an exclusive pick); entries whose prerequisites aren't met yet wait in place while
## the first researchable ones take the slots. Progress on a tech is kept when it leaves the queue.

const TYPE := &"core:cmd/set_research"


func validate(state: MatchState) -> bool:
	if state.empire(player_id) == null:
		return reject("no empire")
	var queue: Variant = payload.get("queue", [])
	if not queue is Array:
		return reject("queue must be a list")
	if (queue as Array).size() > Research.MAX_QUEUE:
		return reject("at most %d queued techs" % Research.MAX_QUEUE)
	var seen := {}
	for t: Variant in queue:
		var tech := str(t)
		if seen.has(tech):
			return reject("%s is queued twice" % tech)
		seen[tech] = true
		var why := Research.blocked(state, player_id, tech)
		if why != "":
			return reject("%s: %s" % [tech, why])
	return true


func apply(state: MatchState) -> void:
	var e := state.empire(player_id)
	e.research_queue.clear()
	for t: Variant in payload["queue"]:
		e.research_queue.append(str(t))
