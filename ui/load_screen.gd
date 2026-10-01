class_name LoadScreen
extends Control
## The archive: saves newest first; activate one to load it (C12). Errors (content mismatch, missing
## mods) are shown here instead of loading.

signal load_requested(path: String)
signal back_requested

var _list: ItemList
var _status: Label
var _paths: Array = []
var dir := SaveGame.DIR  # tests point this elsewhere


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := UiKit.centered_panel(self, 520)
	box.add_child(UiKit.label("LOAD_TITLE", "Title"))
	_list = ItemList.new()
	_list.custom_minimum_size.y = 300
	_list.focus_mode = Control.FOCUS_ALL
	_list.item_activated.connect(func(i: int) -> void: load_requested.emit(_paths[i]))
	box.add_child(_list)
	_status = UiKit.label("", "Caption")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var back := UiKit.button("LOAD_BACK", back_requested.emit)
	var load_button := UiKit.button("LOAD_LOAD", _load_selected)
	buttons.add_child(back)
	buttons.add_child(load_button)
	box.add_child(buttons)
	UiKit.chain_focus([_list, load_button, back])


func refresh() -> void:
	_list.clear()
	_paths.clear()
	_status.text = ""
	for s: Dictionary in SaveGame.list_saves(dir):
		var h := SaveGame.peek(s["path"])
		var date := Calendar.format(int(h.get("tick", 0))) if h.has("tick") else "?"
		_list.add_item("%s    %s" % [s["name"], date])
		_paths.append(s["path"])
	if _paths.is_empty():
		_status.text = TranslationServer.translate("LOAD_EMPTY")


func focus_first() -> void:
	refresh()
	_list.grab_focus()
	if _list.item_count > 0:
		_list.select(0)


func show_error(reasons: Array[String]) -> void:
	_status.add_theme_color_override("font_color", UiTokens.color("signal"))
	_status.text = UiKit.tr_fmt("LOAD_FAILED", {"reason": "; ".join(reasons)})


func _load_selected() -> void:
	var sel := _list.get_selected_items()
	if not sel.is_empty():
		load_requested.emit(_paths[sel[0]])


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()
