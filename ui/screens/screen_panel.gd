class_name ScreenPanel
extends PanelContainer
## Base for the M2 management screens (F6 sector, F7 logistics, F8 colonise, F9 stockpile, F12 alerts):
## a glass panel over the map centre with a title, a close button and a scrolling body. The body is
## rebuilt on open and once per sim day; keyboard focus survives a rebuild (controls are found by name).
## Screens read GameState and submit Commands; they never change state.

signal closed
signal focus_requested(kind: String, id: int)

const MAX_SIZE := Vector2(980, 640)

var title_key := ""
var _title: Label
var _close: Button
var _scroll: ScrollContainer
var _body: VBoxContainer
var _last_day := -1


func _ready() -> void:
	theme_type_variation = "Glass"
	visible = false
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	var box := VBoxContainer.new()
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	_title = UiKit.label(title_key, "Subtitle")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_close = UiKit.button("SCREEN_CLOSE", close)
	_close.name = "Close"
	header.add_child(_close)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	box.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)


func open() -> void:
	var vp := get_viewport_rect().size
	custom_minimum_size = Vector2(minf(MAX_SIZE.x, vp.x - 48.0), minf(MAX_SIZE.y, vp.y - 170.0))
	size = custom_minimum_size
	position = Vector2(roundf((vp.x - custom_minimum_size.x) * 0.5), 96.0)
	visible = true
	rebuild()
	focus_first()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func focus_first() -> void:
	var first := _first_focusable(_body)
	(first if first != null else _close).grab_focus()


func rebuild() -> void:
	var state := GameState.state
	var focused := get_viewport().gui_get_focus_owner()
	var focus_name := String(focused.name) if focused != null and _body.is_ancestor_of(focused) else ""
	for c in _body.get_children():
		_body.remove_child(c)
		c.free()
	if state == null:
		return
	_last_day = state.tick / Calendar.HOURS_PER_DAY
	_fill(state, CommandQueue.local_player)
	if focus_name != "":
		var again := _body.find_child(focus_name, true, false) as Control
		if again != null:
			again.grab_focus()


## Overridden by each screen: add rows to _body.
func _fill(_state: MatchState, _eid: int) -> void:
	pass


func _process(_delta: float) -> void:
	if visible and GameState.state != null and GameState.state.tick / Calendar.HOURS_PER_DAY != _last_day \
			and Engine.get_process_frames() % 15 == 0:
		rebuild()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("view_up"):
		close()
		get_viewport().set_input_as_handled()


# --- builders ---

func heading(key: String, params := {}) -> Label:
	var l := UiKit.label(key, "Caption", params)
	_body.add_child(l)
	return l


func line(text: String, variation := "", parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	(parent if parent != null else _body).add_child(l)
	return l


func button(text: String, node_name: String, on_pressed: Callable, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	b.name = node_name
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(on_pressed)
	(parent if parent != null else _body).add_child(b)
	return b


## A table: a GridContainer with a header row of loc keys.
func table(header_keys: Array, parent: Control = null) -> GridContainer:
	var g := GridContainer.new()
	g.columns = header_keys.size()
	g.add_theme_constant_override("h_separation", 18)
	for key: String in header_keys:
		g.add_child(UiKit.label(key, "Caption"))
	(parent if parent != null else _body).add_child(g)
	return g


func cell(g: GridContainer, text: String, variation := "") -> Label:
	return line(text, variation, g)


func row(parent: Control = null) -> HBoxContainer:
	var h := HBoxContainer.new()
	(parent if parent != null else _body).add_child(h)
	return h


static func _first_focusable(node: Node) -> Control:
	for c in node.get_children():
		if c is Control and (c as Control).focus_mode == Control.FOCUS_ALL and (c as Control).visible:
			return c
		var deeper := _first_focusable(c)
		if deeper != null:
			return deeper
	return null
