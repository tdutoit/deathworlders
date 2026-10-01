extends Node
## Holds the current match (main spec 16.2). Views read `state`; only Commands and tick functions
## change it. The state itself is a plain MatchState (sim/state); this node only owns the reference.

var state: MatchState


## Generates a match from settings and makes it current. Returns errors (empty on success).
func start_new_match(settings: MatchSettings, seed_value: int) -> Array[String]:
	var errors: Array[String] = []
	if Database.report == null or Database.report.has_errors():
		errors.append("content has errors; see the mod report")
		return errors
	var new_state := GalaxyGenerator.new_match(settings, seed_value, Database.defs, errors)
	if new_state == null:
		return errors
	_begin(new_state)
	return errors


## Makes an existing state current (used by save/load).
func adopt(new_state: MatchState) -> void:
	_begin(new_state)


func end_match() -> void:
	state = null
	CommandQueue.reset()
	EventBus.match_ended.emit()


## Empire ID of the first human-controlled slot, or 0.
func first_human_empire() -> int:
	if state == null:
		return 0
	for eid: int in state.empires:
		var e: Empire = state.empires.get_or(eid)
		for p in state.settings.players:
			if int(p["slot"]) == e.player_slot and p["controller"] == "human":
				return eid
	return 0


func _begin(new_state: MatchState) -> void:
	state = new_state
	CommandQueue.reset()
	CommandQueue.local_player = first_human_empire()
	EventBus.match_started.emit()
