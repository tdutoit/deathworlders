class_name ControlRoomTheme
extends RefCounted
## Builds the "Control Room" Theme (Sub-spec F21) from the colour tokens, so palettes swap in one
## place. Jura for UI text, IBM Plex Mono for numbers (both OFL, assets/fonts/).
## Theme type variations: "Title", "Subtitle", "Mono", "Caption" (Label); "Glass" (PanelContainer).

const FONT_UI := "res://assets/fonts/Jura-Variable.ttf"
const FONT_MONO := "res://assets/fonts/IBMPlexMono-Light.ttf"
const BASE_SIZE := 16

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = build()
	return _theme


static func ui_font(weight := 400) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(FONT_UI)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f


static func mono_font() -> Font:
	return load(FONT_MONO)


static func build() -> Theme:
	var t := Theme.new()
	var ink1 := UiTokens.color("ink_1")
	var ink2 := UiTokens.color("ink_2")
	var ink3 := UiTokens.color("ink_3")
	var hair := UiTokens.color("hair")
	var void_c := UiTokens.color("void")
	t.default_font = ui_font(400)
	t.default_font_size = BASE_SIZE

	# Text
	for type in ["Label", "Button", "OptionButton", "LineEdit", "ItemList", "CheckBox", "PopupMenu"]:
		t.set_color("font_color", type, ink1)
	t.set_color("font_disabled_color", "Button", ink3)
	t.set_color("font_disabled_color", "OptionButton", ink3)
	t.set_color("font_hover_color", "Button", ink1)
	t.set_color("font_focus_color", "Button", ink1)
	t.set_color("font_pressed_color", "Button", void_c)
	t.set_color("font_hover_pressed_color", "Button", void_c)
	t.set_color("font_placeholder_color", "LineEdit", ink3)
	t.set_color("caret_color", "LineEdit", ink1)
	t.set_color("font_selected_color", "ItemList", void_c)
	t.set_color("font_hover_color", "PopupMenu", ink1)
	_variation(t, "Title", "Label", ui_font(300), 40, ink1)
	_variation(t, "Subtitle", "Label", ui_font(400), 18, ink2)
	_variation(t, "Caption", "Label", ui_font(500), 13, ink2)
	_variation(t, "Mono", "Label", mono_font(), 16, ink1)

	# Glass panels: translucent, rounded 10, one broad soft shadow, no border (F21).
	var glass := _box(UiTokens.color("panel"), 10)
	glass.shadow_color = Color(ink1, 0.10)
	glass.shadow_size = 24
	glass.set_content_margin_all(16)
	t.set_stylebox("panel", "PanelContainer", glass)
	t.set_type_variation("Glass", "PanelContainer")
	t.set_stylebox("panel", "Glass", glass)
	t.set_stylebox("panel", "PopupMenu", glass)

	# Buttons: quiet ink text; hover gets a hairline wash; pressed/selected inverts (F21 rule 4).
	var normal := _box(Color(0, 0, 0, 0), 6)
	var hover := _box(Color(hair, 0.6), 6)
	var pressed := _box(ink1, 6)
	var disabled := _box(Color(0, 0, 0, 0), 6)
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, _focus_box(ink1))
	t.set_color("font_pressed_color", "OptionButton", void_c)

	# Inputs and lists: hairline underline style.
	var field := _box(Color(void_c, 0.6), 6)
	field.border_width_bottom = 1
	field.border_color = ink3
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", _focus_box(ink1))
	t.set_stylebox("panel", "ItemList", _box(Color(0, 0, 0, 0), 6))
	t.set_stylebox("focus", "ItemList", _focus_box(ink2))
	t.set_stylebox("selected", "ItemList", pressed)
	t.set_stylebox("selected_focus", "ItemList", pressed)
	t.set_stylebox("hovered", "ItemList", hover)
	t.set_stylebox("cursor", "ItemList", _focus_box(ink1))
	t.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("separator", "HSeparator", _line(hair))
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 10)
	return t


static func _variation(t: Theme, name: String, base: String, font: Font, size: int, color: Color) -> void:
	t.set_type_variation(name, base)
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)


static func _box(color: Color, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.content_margin_left = 12
	b.content_margin_right = 12
	b.content_margin_top = 6
	b.content_margin_bottom = 6
	return b


## Visible keyboard focus: a 2 px ink outline (no hover-only cues, main spec 16.7).
static func _focus_box(color: Color) -> StyleBoxFlat:
	var b := _box(Color(0, 0, 0, 0), 6)
	b.draw_center = false
	b.set_border_width_all(2)
	b.border_color = color
	b.set_expand_margin_all(2)
	return b


static func _line(color: Color) -> StyleBoxLine:
	var l := StyleBoxLine.new()
	l.color = color
	l.thickness = 1
	return l
