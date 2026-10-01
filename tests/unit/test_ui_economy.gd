extends GutTest
# M2 WP12: economy UI. Top bar globals, the F4 colony block, the F6/F7/F9/F12 screens and their Commands,
# and the D6 alerts model.

const FOOD := "core:resource/food"

var _main: Node
var _ui: UiRoot


func before_each() -> void:
	GameState.end_match()
	_main = load("res://main.tscn").instantiate()
	add_child_autofree(_main)
	_ui = _main.get_node("UI/UiRoot")
	(_main.get_node("ViewContainer") as ViewManager).reduce_motion = true
	await wait_process_frames(2)
	_ui.main_menu.new_game_requested.emit()
	(_ui.setup.find_child("Start", true, false) as Button).pressed.emit()
	await wait_process_frames(2)


func after_each() -> void:
	GameState.end_match()


func _key(action: String) -> void:
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = pressed
		Input.parse_input_event(e)
		await wait_process_frames(1)


func _earth() -> Colony:
	var state := GameState.state
	return state.colony(state.empire(CommandQueue.local_player).capital_planet)




func test_units_format() -> void:
	assert_eq(UiKit.units(1240000), "1,240")
	assert_eq(UiKit.units(2500), "2.5")
	assert_eq(UiKit.units(0), "0")
	assert_eq(UiKit.signed(-6000), "−6")
	assert_eq(UiKit.signed(12000), "+12")


func test_top_bar_shows_globals_and_alerts() -> void:
	await wait_process_frames(31)
	var credits := _ui.top_bar.find_child("Res_credits", true, false) as Button
	assert_string_contains(credits.text, "₵")
	assert_string_contains((_ui.top_bar.find_child("Alerts", true, false) as Button).text, "△")


func test_function_keys_open_and_close_screens() -> void:
	for pair in [["open_sectors", _ui.sector_screen], ["open_logistics", _ui.logistics_screen],
			["open_stockpile", _ui.stockpile_screen], ["open_alerts", _ui.alerts_screen]]:
		await _key(pair[0])
		assert_true((pair[1] as ScreenPanel).visible, pair[0] + " opens its screen")
		assert_true((pair[1] as ScreenPanel).is_ancestor_of(_ui.get_viewport().gui_get_focus_owner()), "focus moves into it")
		await _key("view_up")
		assert_false((pair[1] as ScreenPanel).visible, "Esc closes it")


func test_only_one_screen_at_a_time() -> void:
	_ui.toggle_screen(_ui.sector_screen)
	_ui.toggle_screen(_ui.stockpile_screen)
	assert_false(_ui.sector_screen.visible)
	assert_true(_ui.stockpile_screen.visible)
	_ui.toggle_screen(_ui.stockpile_screen)
	assert_false(_ui.stockpile_screen.visible, "the same key closes it again")


func test_sector_screen_lists_the_core_sector() -> void:
	_ui.toggle_screen(_ui.sector_screen)
	var texts := []
	for l: Label in _ui.sector_screen.find_children("*", "Label", true, false):
		texts.append(l.text)
	assert_has(texts, "Earth", "the capital is in the Core Sector table")
	assert_not_null(_ui.sector_screen.find_child("Directive_*", true, false), "directive picker")


func test_planet_panel_autonomy_submits_a_command() -> void:
	EventBus.selection_changed.emit("planet", _earth().id)
	var manual := _ui.context_panel.find_child("Autonomy_manual", true, false) as Button
	assert_not_null(manual, "own colonies get the autonomy switch")
	CommandQueue.schedule.clear()
	manual.pressed.emit()
	assert_eq(CommandQueue.schedule.size(), 1)


func test_starvation_alert_with_fix() -> void:
	var c := _earth()
	c.stockpile.take(FOOD, c.stockpile.milli(FOOD))
	c.last_consumed[FOOD] = 30000
	c.last_produced[FOOD] = 0
	var found := {}
	for a: Dictionary in Alerts.collect(GameState.state, CommandQueue.local_player):
		if a["key"] == "ALERT_STARVATION":
			found = a
	assert_false(found.is_empty(), "no food and a deficit raises the starvation alert")
	assert_eq(found["severity"], Alerts.URGENT)
	assert_eq(found["fix"]["type"], CmdSetDemandTarget.TYPE)
	assert_eq(found["fix"]["payload"]["holder"], c.id)
	_ui.toggle_screen(_ui.alerts_screen)
	var fix := _ui.alerts_screen.find_child("Fix_0", true, false) as Button
	assert_not_null(fix, "the most urgent alert is first and has a Fix button")
	CommandQueue.schedule.clear()
	fix.pressed.emit()
	assert_eq(CommandQueue.schedule.size(), 1, "Fix submits the previewed Command")
	var cmd := CommandRegistry.create(found["fix"]["type"], CommandQueue.local_player, found["fix"]["payload"])
	assert_true(cmd.validate(GameState.state), "the fix is a valid Command")


func test_stockpile_filters() -> void:
	_ui.toggle_screen(_ui.stockpile_screen)
	(_ui.stockpile_screen.find_child("Filter_near_full", true, false) as Button).pressed.emit()
	assert_eq(_ui.stockpile_screen._filter, "near_full")
	_ui.stockpile_screen.close()
	_ui.toggle_screen(_ui.logistics_screen)
	(_ui.logistics_screen.find_child("Tab_hubs", true, false) as Button).pressed.emit()
	assert_not_null(_ui.logistics_screen.find_child("Tab_hubs", true, false), "tabs survive the rebuild")
	assert_eq(_ui.logistics_screen._tab, "hubs")


func test_show_planet_dives_into_its_system() -> void:
	var vm := _main.get_node("ViewContainer") as ViewManager
	await vm.focus_on("planet", _earth().id)
	assert_eq(vm.level, "solar", "planets are shown in the tactical scope")
	assert_eq(vm.selected_kind, "planet")
	assert_eq(vm.selected_id, _earth().id)
	await vm.focus_on("unit", 999999)  # a unit that no longer exists is ignored
	assert_eq(vm.level, "solar")
