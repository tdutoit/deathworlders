class_name UiRoot
extends Control
## The UI shell (M1 WP9): main menu -> match setup -> in-match HUD, plus the in-match command menu.
## Applies the Control Room theme and the saved UI scale. Talks to the sim only through GameState
## (start/end match) and CommandQueue.

const MARGIN := 12

var view_manager: ViewManager
var main_menu: MainMenu
var setup: MatchSetup
var hud: Control
var top_bar: TopBar
var context_panel: ContextPanel
var outliner: Outliner
var game_menu: GameMenu

var _resume_unpauses := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = ControlRoomTheme.get_theme()
	get_tree().root.content_scale_factor = UiSettings.ui_scale()
	_build_hud()
	main_menu = MainMenu.new()
	add_child(main_menu)
	setup = MatchSetup.new()
	add_child(setup)
	game_menu = GameMenu.new()
	add_child(game_menu)
	main_menu.new_game_requested.connect(show_setup)
	main_menu.quit_requested.connect(func() -> void: get_tree().quit())
	main_menu.set_load_enabled(false)  # the archive arrives in WP10
	setup.back_requested.connect(show_main_menu)
	setup.start_requested.connect(_on_start)
	game_menu.resume_requested.connect(close_game_menu)
	game_menu.exit_requested.connect(_on_exit)
	game_menu.set_archive_enabled(false)
	outliner.focus_requested.connect(func(kind: String, id: int) -> void:
		if view_manager:
			view_manager.focus_on(kind, id))
	EventBus.match_started.connect(show_hud)
	if GameState.state != null:
		show_hud()
	else:
		show_main_menu()


func _build_hud() -> void:
	hud = Control.new()
	hud.name = "Hud"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	top_bar = TopBar.new()
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, MARGIN)
	hud.add_child(top_bar)
	context_panel = ContextPanel.new()
	context_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	context_panel.position.y = 84
	context_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud.add_child(context_panel)
	outliner = Outliner.new()
	outliner.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN)
	outliner.position.y = 84
	hud.add_child(outliner)
	var hint := UiKit.label("HUD_HINT", "Caption")
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, MARGIN)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.add_child(hint)


func _show_only(screen: Control) -> void:
	for c in [main_menu, setup, hud, game_menu]:
		c.visible = c == screen
	if screen == game_menu:
		hud.visible = true


func show_main_menu() -> void:
	_show_only(main_menu)
	main_menu.focus_first()


func show_setup() -> void:
	_show_only(setup)
	setup.focus_first()


func show_hud() -> void:
	_show_only(hud)
	if get_viewport().gui_get_focus_owner():
		get_viewport().gui_get_focus_owner().release_focus()


func open_game_menu() -> void:
	var state := GameState.state
	_resume_unpauses = state != null and not state.paused
	if _resume_unpauses:
		CommandQueue.submit_new(CmdPause.TYPE, {"paused": 1})
	_show_only(game_menu)
	game_menu.focus_first()


func close_game_menu() -> void:
	if _resume_unpauses and GameState.state:
		CommandQueue.submit_new(CmdPause.TYPE, {"paused": 0})
	_resume_unpauses = false
	show_hud()


func _on_start(settings: MatchSettings, seed_value: int) -> void:
	var errors := GameState.start_new_match(settings, seed_value)
	if not errors.is_empty():
		push_warning("Match setup: " + ", ".join(errors))
		return
	show_hud()


func _on_exit() -> void:
	_resume_unpauses = false
	GameState.end_match()
	show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.state == null or not hud.visible:
		return
	if event.is_action_pressed("open_menu") and not game_menu.visible:
		open_game_menu()
	elif event.is_action_pressed("open_outliner") and not game_menu.visible:
		outliner.take_focus()
	else:
		return
	get_viewport().set_input_as_handled()
