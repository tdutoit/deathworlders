class_name MainMenu
extends Control
## Main menu, presented as the login to the Fleet Command Network (F22).

signal new_game_requested
signal load_requested
signal quit_requested

var first_focus: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := UiKit.centered_panel(self)
	box.add_child(UiKit.label("MENU_TITLE", "Title"))
	box.add_child(UiKit.label("MENU_SUBTITLE", "Subtitle"))
	box.add_child(HSeparator.new())
	var new_game := UiKit.button("MENU_NEW_GAME", new_game_requested.emit)
	var load_game := UiKit.button("MENU_LOAD", load_requested.emit)
	load_game.name = "Load"
	var quit := UiKit.button("MENU_QUIT", quit_requested.emit)
	var scale_row := HBoxContainer.new()
	scale_row.add_child(UiKit.label("SETTINGS_UI_SCALE", "Caption"))
	var items := []
	for s in UiSettings.SCALES:
		items.append(["%d%%" % roundi(s * 100), s])
	var scale := UiKit.options(items, maxi(0, UiSettings.SCALES.find(UiSettings.ui_scale())))
	scale.item_selected.connect(func(i: int) -> void: UiSettings.set_ui_scale(scale.get_item_metadata(i), get_tree()))
	scale_row.add_child(scale)
	for b in [new_game, load_game, quit]:
		box.add_child(b)
	box.add_child(HSeparator.new())
	box.add_child(scale_row)
	UiKit.chain_focus([new_game, load_game, quit, scale])
	first_focus = new_game


func set_load_enabled(enabled: bool) -> void:
	(find_child("Load", true, false) as Button).disabled = not enabled


func focus_first() -> void:
	first_focus.grab_focus()
