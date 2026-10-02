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
var _slots: Array = []  # [species OptionButton, controller OptionButton, difficulty OptionButton, council CheckBox]
var _species_info: Label
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
	slots.columns = 5
	slots.add_theme_constant_override("h_separation", 12)
	box.add_child(slots)
	var species_items := []
	for def in Database.defs.defs("species"):
		species_items.append([def.name_key, String(def.id)])
	var difficulties: Array = Database.defs.defs("difficulty")
	difficulties.sort_custom(func(a: DifficultyDef, b: DifficultyDef) -> bool: return a.order < b.order)
	var diff_items := []
	var officer := 0
	for d: DifficultyDef in difficulties:
		if String(d.id) == MatchSettings.OFFICER:
			officer = diff_items.size()
		diff_items.append([d.name_key, String(d.id)])
	for i in MAX_SLOTS:
		slots.add_child(UiKit.label("SETUP_SLOT", "Caption", {"n": i + 1}))
		var sp := UiKit.options(species_items, i % species_items.size())
		var ctrl := UiKit.options([["CONTROLLER_HUMAN", "human"], ["CONTROLLER_AI", "ai"], ["CONTROLLER_CLOSED", "closed"]],
				0 if i == 0 else (1 if i < 4 else 2))
		var diff := UiKit.options(diff_items, officer)
		diff.tooltip_text = _difficulty_tips(difficulties)
		var seat := CheckBox.new()
		seat.text = TranslationServer.translate("SETUP_COUNCIL_SEAT")
		seat.focus_mode = Control.FOCUS_ALL
		sp.item_selected.connect(func(_i: int) -> void: _show_species(sp.get_selected_metadata()))
		slots.add_child(sp)
		slots.add_child(ctrl)
		slots.add_child(diff)
		slots.add_child(seat)
		_slots.append([sp, ctrl, diff, seat])
	_species_info = UiKit.label("", "Caption")
	_species_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_species_info.custom_minimum_size.x = 520
	box.add_child(_species_info)
	_show_species(_slots[0][0].get_selected_metadata())
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
			s.add_player(i, _slots[i][0].get_selected_metadata(), controller, _slots[i][2].get_selected_metadata(),
				(_slots[i][3] as CheckBox).button_pressed)
	return s


## F15: the species' traits and signature mechanic, listed when its slot's species changes.
func _show_species(species_id: String) -> void:
	var sd := Database.defs.get_def(StringName(species_id)) as SpeciesDef
	if sd == null:
		return
	var traits := []
	for t in sd.traits:
		var td := Database.defs.get_def(t)
		traits.append(TranslationServer.translate(td.name_key) if td else String(t))
	_species_info.text = UiKit.tr_fmt("SETUP_SPECIES_INFO", {"species": TranslationServer.translate(sd.name_key),
		"personality": TranslationServer.translate(sd.personality_key), "traits": ", ".join(traits),
		"signature": TranslationServer.translate("SIGNATURE_" + String(sd.signature_mechanic).to_upper())})


## E13: every bonus listed openly.
static func _difficulty_tips(defs: Array) -> String:
	var lines := []
	for d: DifficultyDef in defs:
		lines.append(UiKit.tr_fmt("DIFFICULTY_TIP", {"name": TranslationServer.translate(d.name_key),
			"desc": TranslationServer.translate(d.desc_key), "output": "%+d%%" % (d.output_permille / 10), "actions": d.actions}))
	return "
".join(lines)


func _on_start() -> void:
	var s := build_settings()
	if not s.players.any(func(p: Dictionary) -> bool: return p["controller"] == "human"):
		_error.text = TranslationServer.translate("SETUP_NEED_HUMAN")
		return
	start_requested.emit(s, DetRng.match_seed_from_text(s.seed_text))
