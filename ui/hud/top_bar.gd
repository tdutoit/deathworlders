class_name TopBar
extends PanelContainer
## Top bar (F2/F22): command console title, current instrument, global resources (credits, research,
## influence with last month's net), date, pause and speed controls, and the alerts count.
## Buttons submit Commands or open screens; the bar only reads state.

signal stockpile_requested
signal alerts_requested

const GLOBALS: Array[String] = ["core:resource/credits", "core:resource/research", "core:resource/influence"]
const SYMBOLS := {"core:resource/credits": "₵", "core:resource/research": "RP", "core:resource/influence": "✦"}  # ⚗/⚠ fall back to colour emoji

var _globals := {}  # resource ID -> Button
var _alerts: Button
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
	for res in GLOBALS:
		var b := Button.new()
		b.name = "Res_" + res.get_slice("/", 1)
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_font_override("font", ControlRoomTheme.mono_font())
		b.pressed.connect(func() -> void: stockpile_requested.emit())
		row.add_child(b)
		_globals[res] = b
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
	_alerts = Button.new()
	_alerts.name = "Alerts"
	_alerts.focus_mode = Control.FOCUS_ALL
	_alerts.add_theme_font_override("font", ControlRoomTheme.mono_font())
	_alerts.pressed.connect(func() -> void: alerts_requested.emit())
	row.add_child(_alerts)
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
	if Engine.get_process_frames() % 30 == 0:
		_refresh_economy(state)


## Treasury and last month's net per global resource; alerts recounted at the same pace.
func _refresh_economy(state: MatchState) -> void:
	var eid := CommandQueue.local_player
	var e := state.empire(eid)
	if e == null:
		return
	var nets := month_nets(state, eid)
	for res: String in _globals:
		var b: Button = _globals[res]
		b.text = "%s %s %s" % [SYMBOLS[res], UiKit.units(int(e.treasury.get(res, 0))), UiKit.signed(int(nets.get(res, 0)))]
		b.tooltip_text = TranslationServer.translate("TOP_" + res.get_slice("/", 1).to_upper())
	var n := Alerts.count(state, eid)
	_alerts.text = "△ %d" % n
	_alerts.tooltip_text = TranslationServer.translate("TOP_ALERTS")


## Last month's net per global resource: credits are income minus upkeep (Empire.credit_net); research
## and influence are what the colonies produced minus what they used.
static func month_nets(state: MatchState, eid: int) -> Dictionary:
	var out := {"core:resource/credits": state.empire(eid).credit_net}
	for pid: int in state.colonies:
		var c: Colony = state.colonies.get_or(pid)
		if c.owner != eid:
			continue
		for res in ["core:resource/research", "core:resource/influence"]:
			out[res] = int(out.get(res, 0)) + int(c.last_produced.get(res, 0)) - int(c.last_consumed.get(res, 0))
	return out


func _toggle_pause() -> void:
	CommandQueue.submit_new(CmdPause.TYPE, {"paused": 0 if GameState.state.paused else 1})
