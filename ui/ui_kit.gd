class_name UiKit
extends RefCounted
## Small builders so screens stay short. Every text goes through tr() with a loc key.


static func label(key: String, variation := "", params := {}) -> Label:
	var l := Label.new()
	l.text = tr_fmt(key, params)
	l.theme_type_variation = variation
	return l


static func button(key: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = TranslationServer.translate(key)
	b.pressed.connect(on_pressed)
	b.focus_mode = Control.FOCUS_ALL
	return b


## OptionButton with (loc key, value) items; `value` is stored as item metadata.
static func options(items: Array, selected := 0) -> OptionButton:
	var o := OptionButton.new()
	for i in items.size():
		o.add_item(TranslationServer.translate(items[i][0]), i)
		o.set_item_metadata(i, items[i][1])
	o.select(selected)
	o.focus_mode = Control.FOCUS_ALL
	return o


static func glass(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Glass"
	p.add_child(child)
	return p


## A glass panel centred in its parent, holding a VBox; returns the VBox.
static func centered_panel(parent: Control, min_width := 420) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = min_width
	center.add_child(glass(box))
	return box


static func tr_fmt(key: String, params := {}) -> String:
	var text := TranslationServer.translate(key)
	return text.format(params) if not params.is_empty() else text


## Chains focus_neighbor_top/bottom through controls in order (wrapping), for D-pad / arrow keys.
static func chain_focus(controls: Array) -> void:
	var n := controls.size()
	for i in n:
		var c: Control = controls[i]
		c.focus_neighbor_top = c.get_path_to(controls[(i - 1 + n) % n])
		c.focus_neighbor_bottom = c.get_path_to(controls[(i + 1) % n])
		c.focus_previous = c.focus_neighbor_top
		c.focus_next = c.focus_neighbor_bottom
