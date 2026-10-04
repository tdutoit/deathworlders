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
var load_screen: LoadScreen
var sector_screen: SectorScreen
var logistics_screen: LogisticsScreen
var stockpile_screen: StockpileScreen
var alerts_screen: AlertsScreen
var colonise_screen: ColoniseScreen
var fleets_screen: FleetsScreen
var designer_screen: DesignerScreen
var battles_screen: BattlesScreen
var diplomacy_screen: DiplomacyScreen
var construction_screen: ConstructionScreen
var _screens: Array[ScreenPanel] = []

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
	load_screen = LoadScreen.new()
	add_child(load_screen)
	main_menu.new_game_requested.connect(show_setup)
	main_menu.quit_requested.connect(func() -> void: get_tree().quit())
	main_menu.load_requested.connect(show_load)
	load_screen.back_requested.connect(func() -> void:
		if GameState.state != null:
			_show_only(game_menu)
			game_menu.focus_first()
		else:
			show_main_menu())
	load_screen.load_requested.connect(_on_load)
	game_menu.save_requested.connect(_on_save)
	game_menu.load_requested.connect(show_load)
	setup.back_requested.connect(show_main_menu)
	setup.start_requested.connect(_on_start)
	game_menu.resume_requested.connect(close_game_menu)
	game_menu.exit_requested.connect(_on_exit)
	outliner.focus_requested.connect(func(kind: String, id: int) -> void:
		if view_manager:
			view_manager.focus_on(kind, id))
	top_bar.stockpile_requested.connect(func() -> void: toggle_screen(stockpile_screen))
	top_bar.alerts_requested.connect(func() -> void: toggle_screen(alerts_screen))
	context_panel.fleet_requested.connect(func(fid: int) -> void:
		_close_screens()
		fleets_screen.only_fleet = fid
		fleets_screen._tab = "fleets"
		fleets_screen.open())
	context_panel.colonise_requested.connect(func(pid: int) -> void:
		_close_screens()
		colonise_screen.open_for(pid))
	context_panel.construction_requested.connect(open_construction)
	alerts_screen.construction_requested.connect(open_construction)
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
	sector_screen = SectorScreen.new()
	logistics_screen = LogisticsScreen.new()
	stockpile_screen = StockpileScreen.new()
	alerts_screen = AlertsScreen.new()
	colonise_screen = ColoniseScreen.new()
	fleets_screen = FleetsScreen.new()
	designer_screen = DesignerScreen.new()
	battles_screen = BattlesScreen.new()
	diplomacy_screen = DiplomacyScreen.new()
	construction_screen = ConstructionScreen.new()
	diplomacy_screen.visibility_changed.connect(func() -> void:  # full screen (F14): side panels step aside
		outliner.visible = not diplomacy_screen.visible
		context_panel.visible = not diplomacy_screen.visible)
	designer_screen.visibility_changed.connect(func() -> void:  # full screen (F10): side panels step aside
		outliner.visible = not designer_screen.visible
		context_panel.visible = not designer_screen.visible)
	_screens = [sector_screen, logistics_screen, stockpile_screen, alerts_screen, colonise_screen, fleets_screen, designer_screen, battles_screen, diplomacy_screen,
		construction_screen]
	for screen in _screens:
		hud.add_child(screen)
		screen.focus_requested.connect(func(kind: String, id: int) -> void:
			screen.close()
			if view_manager:
				view_manager.focus_on(kind, id))
	var hint := UiKit.label("HUD_HINT", "Caption")
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, MARGIN)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.add_child(hint)


func _show_only(screen: Control) -> void:
	for c in [main_menu, setup, hud, game_menu, load_screen]:
		c.visible = c == screen
	if screen == game_menu:
		hud.visible = true


## The Construction screen for a planet (M4 WP15), from the planet panel, an alert or the designer.
func open_construction(pid: int) -> void:
	_close_screens()
	construction_screen.open_for(pid)


## Opens a management screen (closing any other), or closes it if it is already open.
func toggle_screen(screen: ScreenPanel) -> void:
	var was_open := screen.visible
	_close_screens()
	if not was_open:
		screen.open()


func _close_screens() -> void:
	for screen in _screens:
		screen.close()


func show_main_menu() -> void:
	_show_only(main_menu)
	main_menu.focus_first()


func show_setup() -> void:
	_show_only(setup)
	setup.focus_first()


func show_load() -> void:
	_show_only(load_screen)
	load_screen.focus_first()


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


func _on_save() -> void:
	var name := "save_%s" % Calendar.format(GameState.state.tick).replace(" ", "_").replace(":", "")
	var path := SaveGame.DIR.path_join(name + SaveGame.EXT)
	var err := GameState.save_to(path)
	game_menu.set_status(UiKit.tr_fmt("SAVE_FAILED", {"reason": err}) if err != "" else UiKit.tr_fmt("SAVE_DONE", {"name": name}))


func _on_load(path: String) -> void:
	_resume_unpauses = false
	var errors := GameState.load_from(path)
	if not errors.is_empty():
		load_screen.show_error(errors)
		return
	show_hud()


func _on_exit() -> void:
	_resume_unpauses = false
	_close_screens()
	GameState.end_match()
	show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.state == null or not hud.visible:
		return
	if event.is_action_pressed("open_menu") and not game_menu.visible:
		open_game_menu()
	elif event.is_action_pressed("open_outliner") and not game_menu.visible:
		outliner.take_focus()
	elif game_menu.visible:
		return
	elif event.is_action_pressed("open_fleets"):
		fleets_screen.only_fleet = 0
		toggle_screen(fleets_screen)
	elif event.is_action_pressed("open_diplomacy"):
		toggle_screen(diplomacy_screen)
	elif event.is_action_pressed("open_battles"):
		toggle_screen(battles_screen)
	elif event.is_action_pressed("open_designer"):
		toggle_screen(designer_screen)
	elif event.is_action_pressed("open_sectors"):
		toggle_screen(sector_screen)
	elif event.is_action_pressed("open_logistics"):
		toggle_screen(logistics_screen)
	elif event.is_action_pressed("open_stockpile"):
		toggle_screen(stockpile_screen)
	elif event.is_action_pressed("open_alerts"):
		toggle_screen(alerts_screen)
	else:
		return
	get_viewport().set_input_as_handled()
