class_name MatchSetup
extends Control
## Match setup (main spec 17, F15): galaxy size, pace, seed, crisis and player slots.

signal start_requested(settings: MatchSettings, seed_value: int)
signal back_requested

const MAX_SLOTS := 8
const CRISIS: Array[String] = ["off", "early", "normal", "late"]

var first_focus: Control
var _size: OptionButton
var _pace: OptionButton
var _crisis: OptionButton
var _seed: LineEdit
var _slots: Array = []  # [species OptionButton, controller OptionButton]
var _error: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := UiKit.centered_panel(self, 560)
	box.add_child(UiKit.label("SETUP_TITLE", "Title"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	box.add_child(grid)
	_size = _preset_options("galaxy_size", 0)
	_pace = _preset_options("pace", 1)
	var crisis_items := []
	for c in CRISIS:
		crisis_items.append(["CRISIS_" + c.to_upper(), c])
	_crisis = UiKit.options(crisis_items, 2)
	_seed = LineEdit.new()
	_seed.placeholder_text = TranslationServer.translate("SETUP_SEED_HINT")
	_seed.custom_minimum_size.x = 220
	var seed_row := HBoxContainer.new()
	seed_row.add_child(_seed)
	var random := UiKit.button("SETUP_SEED_RANDOM", func() -> void: _seed.text = "")
	seed_row.add_child(random)
	for row: Array in [["SETUP_GALAXY_SIZE", _size], ["SETUP_PACE", _pace], ["SETUP_SEED", seed_row], ["SETUP_CRISIS", _crisis]]:
		grid.add_child(UiKit.label(row[0], "Caption"))
		grid.add_child(row[1])
	box.add_child(HSeparator.new())
	box.add_child(UiKit.label("SETUP_PLAYERS", "Caption"))
	var slots := GridContainer.new()
	slots.columns = 3
	slots.add_theme_constant_override("h_separation", 12)
	box.add_child(slots)
	var species_items := []
	for def in Database.defs.defs("species"):
		species_items.append([def.name_key, String(def.id)])
	for i in MAX_SLOTS:
		slots.add_child(UiKit.label("SETUP_SLOT", "Caption", {"n": i + 1}))
		var sp := UiKit.options(species_items, i % species_items.size())
		var ctrl := UiKit.options([["CONTROLLER_HUMAN", "human"], ["CONTROLLER_AI", "ai"], ["CONTROLLER_CLOSED", "closed"]],
				0 if i == 0 else (1 if i < 4 else 2))
		slots.add_child(sp)
		slots.add_child(ctrl)
		_slots.append([sp, ctrl])
	_error = UiKit.label("", "Caption")
	_error.add_theme_color_override("font_color", UiTokens.color("signal"))
	box.add_child(_error)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var back := UiKit.button("SETUP_BACK", back_requested.emit)
	var start := UiKit.button("SETUP_START", _on_start)
	start.name = "Start"
	buttons.add_child(back)
	buttons.add_child(start)
	box.add_child(buttons)
	# Arrow-key order: top to bottom, then Start, Back.
	var order: Array = [_size, _pace, _seed, random, _crisis]
	for s: Array in _slots:
		order.append_array(s)
	order.append_array([start, back])
	UiKit.chain_focus(order)
	first_focus = _size


func _preset_options(kind: String, selected: int) -> OptionButton:
	var presets := []
	for def in Database.defs.defs("match_preset"):
		if (def as MatchPresetDef).kind == StringName(kind):
			presets.append(def)
	presets.sort_custom(func(a: MatchPresetDef, b: MatchPresetDef) -> bool: return a.sort_order < b.sort_order)
	var items := []
	for p: MatchPresetDef in presets:
		items.append([p.name_key, String(p.id)])
	return UiKit.options(items, selected)


func focus_first() -> void:
	_error.text = ""
	first_focus.grab_focus()


## Settings from the form; seed_text empty means a random seed (drawn here, outside the sim).
func build_settings() -> MatchSettings:
	var s := MatchSettings.new()
	s.galaxy_size = _size.get_selected_metadata()
	s.pace = _pace.get_selected_metadata()
	s.crisis = _crisis.get_selected_metadata()
	s.seed_text = _seed.text.strip_edges()
	if s.seed_text == "":
		s.seed_text = str(randi())
	for i in _slots.size():
		var controller: String = _slots[i][1].get_selected_metadata()
		if controller != "closed":
			s.add_player(i, _slots[i][0].get_selected_metadata(), controller)
	return s


func _on_start() -> void:
	var s := build_settings()
	if not s.players.any(func(p: Dictionary) -> bool: return p["controller"] == "human"):
		_error.text = TranslationServer.translate("SETUP_NEED_HUMAN")
		return
	start_requested.emit(s, DetRng.match_seed_from_text(s.seed_text))
