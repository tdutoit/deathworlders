class_name TopBar
extends PanelContainer
## Top bar (F2/F22): command console title, current instrument, date, pause and speed controls.
## Buttons submit Commands; the bar only reads state.

var _title: Label
var _view: Label
var _date: Label
var _pause: Button
var _speeds := {}  # speed -> Button


func _ready() -> void:
	theme_type_variation = "Glass"
	var row := HBoxContainer.new()
	add_child(row)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	_title = UiKit.label("", "")
	_view = UiKit.label("VIEW_GALAXY", "Caption")
	titles.add_child(_title)
	titles.add_child(_view)
	row.add_child(titles)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_date = UiKit.label("", "Mono")
	row.add_child(_date)
	_pause = UiKit.button("HUD_PAUSE", _toggle_pause)
	_pause.toggle_mode = true
	row.add_child(_pause)
	for s in CmdSetSpeed.SPEEDS:
		var b := Button.new()
		b.text = "%d×" % s
		b.toggle_mode = true
		b.add_theme_font_override("font", ControlRoomTheme.mono_font())
		b.pressed.connect(func() -> void: CommandQueue.submit_new(CmdSetSpeed.TYPE, {"speed": s}))
		row.add_child(b)
		_speeds[s] = b
	EventBus.view_changed.connect(_on_view_changed)
	EventBus.match_started.connect(_refresh_title)


func _refresh_title() -> void:
	var e: Empire = GameState.state.empires.get_or(CommandQueue.local_player) if GameState.state else null
	_title.text = TranslationServer.translate("COMMAND_" + e.species.get_slice("/", 1).to_upper()) if e else ""


func _on_view_changed(level: String, _focus: int) -> void:
	_view.text = TranslationServer.translate("VIEW_" + level.to_upper())


func _process(_delta: float) -> void:
	var state := GameState.state
	if state == null:
		return
	if _title.text == "":
		_refresh_title()
	_date.text = Calendar.format(state.tick)
	_pause.set_pressed_no_signal(state.paused)
	_pause.text = TranslationServer.translate("HUD_RESUME" if state.paused else "HUD_PAUSE")
	for s: int in _speeds:
		(_speeds[s] as Button).set_pressed_no_signal(s == state.speed)


func _toggle_pause() -> void:
	CommandQueue.submit_new(CmdPause.TYPE, {"paused": 0 if GameState.state.paused else 1})
