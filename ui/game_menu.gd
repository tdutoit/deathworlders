class_name GameMenu
extends Control
## In-match command menu (F10): resume, archive (save/load), exit to the main menu.

signal resume_requested
signal save_requested
signal load_requested
signal exit_requested

var first_focus: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # the map underneath ignores clicks while open
	var shade := ColorRect.new()
	shade.color = Color(UiTokens.color("void"), 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var box := UiKit.centered_panel(self, 320)
	box.add_child(UiKit.label("GAME_MENU_TITLE", "Subtitle"))
	var resume := UiKit.button("GAME_MENU_RESUME", resume_requested.emit)
	var save := UiKit.button("GAME_MENU_SAVE", save_requested.emit)
	save.name = "Save"
	var load_game := UiKit.button("GAME_MENU_LOAD", load_requested.emit)
	load_game.name = "Load"
	var exit := UiKit.button("GAME_MENU_EXIT", exit_requested.emit)
	for b in [resume, save, load_game, exit]:
		box.add_child(b)
	UiKit.chain_focus([resume, save, load_game, exit])
	first_focus = resume


func set_archive_enabled(enabled: bool) -> void:
	(find_child("Save", true, false) as Button).disabled = not enabled
	(find_child("Load", true, false) as Button).disabled = not enabled


func focus_first() -> void:
	first_focus.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_menu")):
		resume_requested.emit()
		get_viewport().set_input_as_handled()
