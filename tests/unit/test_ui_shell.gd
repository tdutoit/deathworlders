extends GutTest
# M1 WP9: menu -> setup -> galaxy -> back to the menu, keyboard-only and by mouse (button presses).

var _main: Node
var _ui: UiRoot


func before_each() -> void:
	GameState.end_match()
	_main = load("res://main.tscn").instantiate()
	add_child_autofree(_main)
	_ui = _main.get_node("UI/UiRoot")
	(_main.get_node("ViewContainer") as ViewManager).reduce_motion = true
	await wait_process_frames(2)


func after_each() -> void:
	GameState.end_match()


## Press and release an action, as a key would.
func _key(action: String) -> void:
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = pressed
		Input.parse_input_event(e)
		await wait_process_frames(1)


func _focused() -> Control:
	return _ui.get_viewport().gui_get_focus_owner()


func test_strings_are_localised() -> void:
	assert_eq(TranslationServer.translate("MENU_TITLE"), "Deathworlders")
	assert_eq(TranslationServer.translate("COMMAND_HUMAN"), "Terran Union Fleet Command")


func test_every_ui_loc_key_exists() -> void:
	var re := RegEx.create_from_string("\"([A-Z][A-Z0-9]*_[A-Z0-9_]+)\"")
	var missing := []
	for dir in ["res://ui", "res://ui/hud", "res://ui/screens"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			for m in re.search_all(FileAccess.get_file_as_string(dir.path_join(f))):
				var key := m.get_string(1)
				if TranslationServer.translate(key) == key:
					missing.append("%s: %s" % [f, key])
	assert_eq(missing, [], "loc keys missing from loc/en.csv")


func test_keyboard_only_flow() -> void:
	assert_true(_ui.main_menu.visible)
	assert_eq(_focused().text, "New game", "menu opens with focus on New game")
	await _key("ui_accept")
	assert_true(_ui.setup.visible, "Enter opens the setup")
	await _key("ui_up")  # wraps to Back
	await _key("ui_up")  # Start
	assert_eq(_focused().name, &"Start")
	await _key("ui_accept")
	assert_not_null(GameState.state, "match started")
	assert_true(_ui.hud.visible)
	await _key("open_menu")
	assert_true(_ui.game_menu.visible, "F10 opens the command menu")
	for i in 3:
		await _key("ui_down")  # Resume -> Save -> Load -> Exit
	await _key("ui_accept")
	assert_null(GameState.state, "exit closed the match")
	assert_true(_ui.main_menu.visible, "back at the main menu")


func test_mouse_flow() -> void:
	_ui.main_menu.new_game_requested.emit()  # = clicking New game
	assert_true(_ui.setup.visible)
	(_ui.setup.find_child("Start", true, false) as Button).pressed.emit()
	assert_not_null(GameState.state)
	assert_true(_ui.hud.visible)
	_ui.open_game_menu()
	_ui.game_menu.exit_requested.emit()
	assert_null(GameState.state)
	assert_true(_ui.main_menu.visible)


func test_setup_builds_settings() -> void:
	_ui.show_setup()
	var s := _ui.setup.build_settings()
	assert_eq(s.galaxy_size, "core:match_preset/size_small")
	assert_eq(s.pace, "core:match_preset/pace_standard")
	assert_eq(s.players.size(), 4, "slots 1-4 open by default")
	assert_eq(s.players[0]["controller"], "human")
	assert_ne(s.seed_text, "", "an empty seed becomes a random one")


func test_menu_pauses_and_resume_restores() -> void:
	_ui.main_menu.new_game_requested.emit()
	(_ui.setup.find_child("Start", true, false) as Button).pressed.emit()
	var state := GameState.state
	Sim.execute(state, [CommandRegistry.create(CmdPause.TYPE, CommandQueue.local_player, {"paused": 0})] as Array[Command])
	_ui.open_game_menu()
	Sim.execute(state, CommandQueue.schedule.take_due(state.tick))
	assert_true(state.paused, "opening the menu pauses")
	_ui.close_game_menu()
	Sim.execute(state, CommandQueue.schedule.take_due(state.tick))
	assert_false(state.paused, "resume restores running")


func test_outliner_lists_own_things_and_focuses() -> void:
	_ui.main_menu.new_game_requested.emit()
	(_ui.setup.find_child("Start", true, false) as Button).pressed.emit()
	await wait_process_frames(25)
	var list: ItemList = _ui.outliner._list
	var texts := []
	for i in list.item_count:
		texts.append(list.get_item_text(i).strip_edges())
	assert_has(texts, "Sol", "own capital system listed")
	_ui.outliner.take_focus()
	assert_true(_ui.outliner.has_list_focus())


func test_context_panel_shows_selection() -> void:
	_ui.main_menu.new_game_requested.emit()
	(_ui.setup.find_child("Start", true, false) as Button).pressed.emit()
	var state := GameState.state
	var human: Empire = state.empires.get_or(GameState.first_human_empire())
	EventBus.selection_changed.emit("planet", human.capital_planet)
	var texts := []
	for c in _ui.context_panel._box.get_children():
		if c is Label:
			texts.append((c as Label).text)
	assert_has(texts, "Earth")
	assert_has(texts, "Capital")
	assert_has(texts, "Type: Terran")
