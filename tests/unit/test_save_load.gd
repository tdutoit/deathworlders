extends GutTest
# M1 WP10: save/load (Sub-spec C12).

const DIR := "user://test_saves"

var _db: DefDatabase
var _manifests: Dictionary


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db
	_manifests = loader.manifests


func after_all() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(f))


func _new_match(seed_value := 77) -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	settings.add_player(1, "core:species/vesskar", "ai")
	var errors: Array[String] = []
	return GalaxyGenerator.new_match(settings, seed_value, _db, errors)


## A scripted session: commands submitted at given ticks (some still pending at save points).
func _script(s: MatchState) -> Dictionary:
	var human: Empire = s.empires.get_or(s.empires.keys()[0])
	var home := s.galaxy.planet(human.capital_planet).system_id
	var far: int = s.galaxy.systems.keys()[-1]
	var mid: int = s.galaxy.systems.keys()[s.galaxy.systems.size() / 2]
	return {
		0: [[CmdPause.TYPE, {"paused": 0}], [CmdDebugSpawnScout.TYPE, {"system": home}]],
		10: [[CmdMoveUnit.TYPE, {"unit": "SCOUT", "to": far}]],
		499: [[CmdMoveUnit.TYPE, {"unit": "SCOUT", "to": mid}], [CmdSetSpeed.TYPE, {"speed": 4}]],
		900: [[CmdDebugSpawnScout.TYPE, {"system": far}]],
		1200: [[CmdMoveUnit.TYPE, {"unit": "SCOUT", "to": home}]],
	}


func _run(s: MatchState, sched: CommandSchedule, script: Dictionary, until: int) -> void:
	var player: int = s.empires.keys()[0]
	while s.tick < until:
		for entry: Array in script.get(s.tick, []):
			var payload: Dictionary = entry[1].duplicate()
			if payload.get("unit") is String:
				payload["unit"] = s.units.keys()[0]
			sched.submit(CommandRegistry.create(entry[0], player, payload), s.tick)
		Sim.step(s, sched.take_due(s.tick))


func test_save_load_continue_matches_uninterrupted_run() -> void:
	const N := 500  # the move submitted at 499 is still pending (exec 501) when we save
	var live := _new_match()
	var script := _script(live)
	var live_sched := CommandSchedule.new()
	_run(live, live_sched, script, N)
	assert_gt(live_sched.size(), 0, "a command is in flight at the save point")
	var path := DIR.path_join("acceptance.sav")
	assert_eq(SaveGame.write(path, live, live_sched, _db, _manifests), "")
	var loaded := SaveGame.read(path, _db, _manifests)
	assert_eq(loaded.errors, [] as Array[String])
	var resumed := loaded.state
	var resumed_sched := CommandSchedule.new()
	resumed_sched.restore(loaded.pending)
	assert_eq(resumed.checksum(), live.checksum(), "identical right after loading")
	_run(live, live_sched, script, N + 1000)
	_run(resumed, resumed_sched, script, N + 1000)
	assert_eq(resumed.checksum(), live.checksum(), "identical 1000 ticks later")


func test_header_and_compression() -> void:
	var s := _new_match()
	var path := DIR.path_join("header.sav")
	assert_eq(SaveGame.write(path, s, CommandSchedule.new(), _db, _manifests), "")
	var h := SaveGame.peek(path)
	assert_eq(int(h["save_format"]), SaveGame.FORMAT)
	assert_eq(h["game_version"], ContentLoader.game_version())
	assert_eq(h["content_hash"], "%08x" % _db.content_hash)
	assert_eq(h["mods"][0]["id"], "core")
	assert_eq(int(h["match_seed"]), s.match_seed)
	assert_true(h.has("rng_states") and h.has("settings") and h.has("command_log_tail"))
	assert_false(h.has("state"), "peek drops the bulky state")
	var raw := JSON.stringify(s.to_dict()).length()
	assert_lt(FileAccess.get_file_as_bytes(path).size(), raw / 2, "deflate compresses the JSON")


func test_content_mismatch_is_refused() -> void:
	var path := DIR.path_join("mismatch.sav")
	SaveGame.write(path, _new_match(), CommandSchedule.new(), _db, _manifests)
	var patched := ContentLoader.new()
	patched.load_mods(["res://tests/fixtures/mods/patch_mod"] as Array[String])
	var result := SaveGame.read(path, patched.db, patched.manifests)
	assert_null(result.state)
	assert_string_contains("; ".join(result.errors), "content differs")


func test_missing_mod_is_refused() -> void:
	var with_mod := ContentLoader.new()
	with_mod.load_mods(["res://tests/fixtures/mods/add_mod"] as Array[String])
	var path := DIR.path_join("modded.sav")
	SaveGame.write(path, _new_match(), CommandSchedule.new(), with_mod.db, with_mod.manifests)
	var result := SaveGame.read(path, _db, _manifests)
	assert_null(result.state)
	assert_string_contains("; ".join(result.errors), "missing mods: add_mod 1.0.0")


func test_garbage_file_is_refused() -> void:
	var path := DIR.path_join("garbage.sav")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("not a save")
	f.close()
	var result := SaveGame.read(path, _db, _manifests)
	assert_null(result.state)
	assert_eq(result.errors.size(), 1)


func test_autosave_rotates_three_slots() -> void:
	var slots := []
	for month in range(1, 7):
		slots.append(SaveGame.autosave_path(month * Calendar.HOURS_PER_MONTH).get_file())
	assert_eq(slots, ["autosave_2.sav", "autosave_3.sav", "autosave_1.sav", "autosave_2.sav", "autosave_3.sav", "autosave_1.sav"])


func test_game_state_save_and_load_restore_queue() -> void:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	assert_eq(GameState.start_new_match(settings, 5), [] as Array[String])
	var home := GameState.state.galaxy.planet((GameState.state.empires.values()[0] as Empire).capital_planet).system_id
	CommandQueue.submit_new(CmdDebugSpawnScout.TYPE, {"system": home})
	var before := GameState.state.checksum()
	var path := DIR.path_join("autoload.sav")
	assert_eq(GameState.save_to(path), "")
	GameState.end_match()
	assert_eq(GameState.load_from(path), [] as Array[String])
	assert_eq(GameState.state.checksum(), before)
	assert_eq(CommandQueue.schedule.size(), 1, "pending command restored")
	assert_eq(CommandQueue.local_player, GameState.first_human_empire())
	GameState.end_match()


func test_load_screen_lists_and_loads() -> void:
	var path := DIR.path_join("for_ui.sav")
	SaveGame.write(path, _new_match(), CommandSchedule.new(), _db, _manifests)
	var screen := LoadScreen.new()
	screen.dir = DIR
	add_child_autofree(screen)
	screen.refresh()
	assert_gt(screen._list.item_count, 0)
	watch_signals(screen)
	screen._list.select(screen._paths.find(path))
	screen._load_selected()
	assert_signal_emitted_with_parameters(screen, "load_requested", [path])
