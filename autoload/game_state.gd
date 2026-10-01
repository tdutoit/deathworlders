extends Node
## Holds the current match (main spec 16.2). Views read `state`; only Commands and tick functions
## change it. The state itself is a plain MatchState (sim/state); this node only owns the reference.

var state: MatchState
var autosave_enabled := true
var _autosave_task := -1  # WorkerThreadPool task of the autosave being written, or -1


func _ready() -> void:
	GameClock.month_passed.connect(_on_month)


## Saves the current match (state + pending commands). Returns an error string or "".
func save_to(path: String) -> String:
	if state == null:
		return "no match running"
	return SaveGame.write(path, state, CommandQueue.schedule, Database.defs, Database.manifests)


## Loads a save and makes it current. Returns errors (empty on success).
func load_from(path: String) -> Array[String]:
	finish_autosave()  # it may be writing the very file being loaded
	var save := SaveGame.read(path, Database.defs, Database.manifests)
	if not save.errors.is_empty():
		return save.errors
	_begin(save.state)
	CommandQueue.schedule.restore(save.pending)
	return save.errors


func _on_month(tick: int) -> void:
	if autosave_enabled and state != null:
		finish_autosave()  # one at a time (a month at 8x is ~4 s, a write ~30 ms)
		_autosave_task = SaveGame.write_async(SaveGame.autosave_path(tick), state, CommandQueue.schedule, Database.defs,
			Database.manifests)


## Waits for an autosave still being written (before the next one, and on exit).
func finish_autosave() -> void:
	if _autosave_task != -1:
		WorkerThreadPool.wait_for_task_completion(_autosave_task)
		_autosave_task = -1


func _exit_tree() -> void:
	finish_autosave()


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
	finish_autosave()
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
	if state.defs == null:
		state.defs = Database.defs
	CommandQueue.reset()
	CommandQueue.local_player = first_human_empire()
	EventBus.match_started.emit()
