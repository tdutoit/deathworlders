class_name Outliner
extends PanelContainer
## Outliner stub (F2): the local empire's units and systems. Activating a row focuses the camera on
## it. Tab (open_outliner) moves keyboard focus here; Esc returns to the map.

signal focus_requested(kind: String, id: int)

var _list: ItemList
var _signature := ""


func _ready() -> void:
	theme_type_variation = "Glass"
	custom_minimum_size = Vector2(260, 220)
	var box := VBoxContainer.new()
	add_child(box)
	box.add_child(UiKit.label("OUTLINER_TITLE", "Caption"))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size.y = 180
	_list.focus_mode = Control.FOCUS_ALL
	_list.item_activated.connect(_on_activated)
	_list.item_clicked.connect(func(i: int, _pos: Vector2, _button: int) -> void: _on_activated(i))
	box.add_child(_list)


func take_focus() -> void:
	if _list.item_count > 0:
		if not _list.is_anything_selected():
			_list.select(0)
		_list.grab_focus()


func has_list_focus() -> bool:
	return _list.has_focus()


func _process(_delta: float) -> void:
	var state := GameState.state
	if state == null or Engine.get_process_frames() % 20 != 0:
		return
	var me := CommandQueue.local_player
	var rows := []  # [text, kind, id]
	rows.append([TranslationServer.translate("OUTLINER_UNITS"), "", 0])
	for uid: int in state.units:
		var u: Unit = state.units.get_or(uid)
		if u.owner == me:
			rows.append(["  %s · %s" % [TranslationServer.translate("UNIT_" + u.kind.to_upper()), state.galaxy.system(u.system_id).name], "unit", uid])
	rows.append([TranslationServer.translate("OUTLINER_SYSTEMS"), "", 0])
	for sid: int in state.galaxy.systems:
		var s := state.galaxy.system(sid)
		if s.owner == me:
			rows.append(["  " + s.name, "system", sid])
	var signature := str(rows)
	if signature == _signature:
		return
	_signature = signature
	var keep := _list.get_selected_items()
	_list.clear()
	for r: Array in rows:
		var i := _list.add_item(r[0])
		_list.set_item_metadata(i, [r[1], r[2]])
		_list.set_item_selectable(i, r[1] != "")
		if r[1] == "":
			_list.set_item_custom_fg_color(i, UiTokens.color("ink_2"))
	if not keep.is_empty() and keep[0] < _list.item_count:
		_list.select(keep[0])


func _on_activated(i: int) -> void:
	var meta: Array = _list.get_item_metadata(i)
	if meta[0] != "":
		focus_requested.emit(meta[0], meta[1])


func _input(event: InputEvent) -> void:
	if _list.has_focus() and event.is_action_pressed("ui_cancel"):
		_list.release_focus()
		get_viewport().set_input_as_handled()
