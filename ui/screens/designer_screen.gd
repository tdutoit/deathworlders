class_name DesignerScreen
extends ScreenPanel
## Ship Designer (F3; Sub-spec F10). Pick one of your designs or start from a hull; fit a component per slot
## (only parts that fit are offered); live stats and cost; a 3D preview with turrets on their hardpoints;
## "vs enemy design" runs MatchupPredictor on click (owner decision 2026-10-02); save, save as new, delete,
## export and import design codes (C5). Saving and deleting are Commands; the edit itself is local.

var _design_id := 0  # the own design being edited (0 = unsaved)
var _hull := ""
var _components: Array[String] = []
var _name := ""
var _enemy := 0  # design ID to predict against
var _prediction := ""
var _code_status := ""
var _preview: DesignPreview


func _init() -> void:
	title_key = "DESIGNER_TITLE"


## Nearly full screen (F10 is a full-screen tool).
func open() -> void:
	super.open()
	var vp := get_viewport_rect().size
	custom_minimum_size = Vector2(vp.x - 48.0, vp.y - 150.0)
	size = custom_minimum_size
	position = Vector2(24.0, 96.0)
	if _hull == "":
		_start_from_first_design()
		rebuild()


## The designer changes only on input, not with the sim day.
func _process(_delta: float) -> void:
	pass


func _start_from_first_design() -> void:
	var state := GameState.state
	for did: int in state.designs.ordered():
		var d: ShipDesign = state.designs.get_or(did)
		if d.owner == CommandQueue.local_player:
			_load_design(d)
			return


func _load_design(d: ShipDesign) -> void:
	_design_id = d.id
	_hull = d.hull
	_components.assign(d.components)
	_name = TranslationServer.translate(d.name)
	_prediction = ""


func _fill(state: MatchState, eid: int) -> void:
	if _hull == "":
		heading("DESIGNER_NO_DESIGNS")
		return
	var hull := state.defs.get_def(StringName(_hull)) as HullDef
	# Header: design picker, hull picker, name.
	var top := row()
	var designs := [["DESIGNER_UNSAVED", 0]]
	var sel := 0
	for did: int in state.designs.ordered():
		var d: ShipDesign = state.designs.get_or(did)
		if d.owner == eid:
			if d.id == _design_id:
				sel = designs.size()
			designs.append([d.name, d.id])
	var dpick := UiKit.options(designs, sel)
	dpick.name = "DesignPick"
	dpick.item_selected.connect(func(i: int) -> void:
		var d: ShipDesign = state.designs.get_or(int(dpick.get_item_metadata(i)))
		if d != null:
			_load_design(d)
			rebuild.call_deferred())
	top.add_child(dpick)
	var hulls := []
	var hsel := 0
	for def in state.defs.defs("hull"):
		var h: HullDef = def
		if h.role == &"warship" and String(h.species) == state.empire(eid).species:
			if String(h.id) == _hull:
				hsel = hulls.size()
			hulls.append([h.name_key, String(h.id)])
	var hpick := UiKit.options(hulls, hsel)
	hpick.name = "HullPick"
	hpick.item_selected.connect(func(i: int) -> void:
		_hull = String(hpick.get_item_metadata(i))
		var nh := state.defs.get_def(StringName(_hull)) as HullDef
		_components.clear()
		for s in nh.slots:
			_components.append("")
		_design_id = 0
		_prediction = ""
		rebuild.call_deferred())
	top.add_child(hpick)
	var name_edit := LineEdit.new()
	name_edit.name = "DesignName"
	name_edit.text = _name
	name_edit.custom_minimum_size.x = 220
	name_edit.text_changed.connect(func(t: String) -> void: _name = t)
	top.add_child(name_edit)
	# Middle: slots | preview | stats.
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(mid)
	var slots := VBoxContainer.new()
	slots.custom_minimum_size.x = 300
	mid.add_child(slots)
	line(TranslationServer.translate("DESIGNER_SLOTS"), "Caption", slots)
	for i in hull.slots.size():
		_slot_row(state, hull, i, slots)
	_preview = DesignPreview.new()
	mid.add_child(_preview)
	_preview.show_design.call_deferred(hull, _components.duplicate())
	var stats := VBoxContainer.new()
	stats.custom_minimum_size.x = 260
	mid.add_child(stats)
	_stats(state, eid, hull, stats)
	# Bottom: prediction and actions.
	_predict_row(state, eid)
	_actions(state, eid)


func _slot_row(state: MatchState, hull: HullDef, i: int, parent: Control) -> void:
	var slot: SlotDef = hull.slots[i]
	var r := row(parent)
	line("%s-%s" % [SlotDef.type_names()[slot.slot_type].substr(0, 1).to_upper(), SlotDef.size_names()[slot.slot_size]], "Mono", r)
	var items := [["DESIGNER_EMPTY", ""]]
	var sel := 0
	for def in state.defs.defs("component"):
		var c: ComponentDef = def
		if c.fits(slot):
			if String(c.id) == _components[i]:
				sel = items.size()
			items.append([c.name_key, String(c.id)])
	var opt := UiKit.options(items, sel)
	opt.name = "Slot_%d" % i
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.item_selected.connect(func(k: int) -> void:
		_components[i] = String(opt.get_item_metadata(k))
		_prediction = ""
		rebuild.call_deferred())
	r.add_child(opt)


func _stats(state: MatchState, eid: int, hull: HullDef, parent: Control) -> void:
	var st := ShipStats.of(state.defs, _hull, _components, SpeciesTraits.source_of(state, eid))
	line(TranslationServer.translate("DESIGNER_STATS"), "Caption", parent)
	for pair in [["DESIGNER_HULL", st.hull], ["DESIGNER_ARMOR", st.armor], ["DESIGNER_SHIELD", st.shield],
			["DESIGNER_EVASION", st.evasion], ["DESIGNER_SPEED", st.speed], ["DESIGNER_PD", st.pd],
			["DESIGNER_AMMO", st.ammo], ["DESIGNER_CREW", st.crew], ["DESIGNER_MARINES", st.marines]]:
		line(UiKit.tr_fmt(pair[0], {"n": pair[1]}), "Mono", parent)
	var dmg := 0
	for w in st.weapons:
		dmg += w.damage * w.shots
	line(UiKit.tr_fmt("DESIGNER_VOLLEY", {"n": dmg, "w": st.weapons.size()}), "Mono", parent)
	var cost := ShipStats.cost(state.defs, _hull, _components)
	var parts: Array[String] = []
	for res: String in IdMap.sort_keys(cost.keys()):
		parts.append("%d %s" % [cost[res], UiNames.def_name(res)])
	line(UiKit.tr_fmt("DESIGNER_COST", {"cost": ", ".join(parts)}), "", parent).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var problem := Designs.check(state, eid, _name if _name != "" else "x", _hull, _components)
	if problem != "":
		line(UiKit.tr_fmt("DESIGNER_PROBLEM", {"why": problem}), "", parent).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _predict_row(state: MatchState, eid: int) -> void:
	var r := row()
	line(TranslationServer.translate("DESIGNER_VS"), "Caption", r)
	var items := []
	var sel := 0
	for did: int in state.designs.ordered():
		var d: ShipDesign = state.designs.get_or(did)
		if d.owner != eid:
			if _enemy == 0:
				_enemy = d.id
			if d.id == _enemy:
				sel = items.size()
			items.append([UiKit.tr_fmt("DESIGNER_ENEMY", {"empire": UiNames.owner(state, d.owner),
				"design": TranslationServer.translate(d.name)}), d.id])
	if items.is_empty():
		line(TranslationServer.translate("DESIGNER_NO_ENEMIES"), "", r)
		return
	var opt := UiKit.options(items, sel)
	opt.name = "EnemyPick"
	opt.item_selected.connect(func(k: int) -> void:
		_enemy = int(opt.get_item_metadata(k))
		_prediction = "")
	r.add_child(opt)
	button(TranslationServer.translate("DESIGNER_PREDICT"), "Predict", func() -> void:
		var e: ShipDesign = state.designs.get_or(_enemy)
		var res := MatchupPredictor.predict(state.defs, _hull, _components, e.hull, e.components,
			state.empire(eid).species, SpeciesTraits.source_of(state, e.owner))
		_prediction = TranslationServer.translate(res["error"]) if res.has("error") else UiKit.tr_fmt("DESIGNER_PREDICTION", res)
		rebuild.call_deferred(), r)
	if _prediction != "":
		line(_prediction, "Mono", r)


## "Build at": the saved design at one of the empire's shipyards that can build it (M4 WP15).
func _build_at(state: MatchState, eid: int, r: Control) -> void:
	var yards := OptionButton.new()
	yards.name = "BuildAtYard"
	yards.focus_mode = Control.FOCUS_ALL
	for sid: int in state.stations.ordered():
		var s: Station = state.stations.get_or(sid)
		if s.owner == eid and Shipyards.check_design_ship(state, eid, sid, _design_id) == "":
			yards.add_item(state.galaxy.planet(s.planet_id).name)
			yards.set_item_metadata(yards.item_count - 1, sid)
	if yards.item_count == 0:
		yards.free()
		line(TranslationServer.translate("DESIGNER_NO_YARD"), "Caption", r)
		return
	r.add_child(yards)
	var design := _design_id
	button(TranslationServer.translate("DESIGNER_BUILD_AT"), "BuildAt", func() -> void:
		CommandQueue.submit_new(CmdQueueShip.TYPE, {"station": int(yards.get_selected_metadata()), "design": design}), r)


func _actions(state: MatchState, eid: int) -> void:
	var r := row()
	var payload := {"name": _name, "hull": _hull, "components": Array(_components)}
	if _design_id != 0:
		button(TranslationServer.translate("DESIGNER_SAVE"), "Save", func() -> void:
			var p := payload.duplicate()
			p["design"] = _design_id
			CommandQueue.submit_new(CmdSaveDesign.TYPE, p), r)
	button(TranslationServer.translate("DESIGNER_SAVE_NEW"), "SaveNew", func() -> void:
		CommandQueue.submit_new(CmdSaveDesign.TYPE, payload)
		_design_id = 0
		_pick_newest_after_save.call_deferred(), r)
	if _design_id != 0:
		_build_at(state, eid, r)
		button(TranslationServer.translate("DESIGNER_DELETE"), "Delete", func() -> void:
			CommandQueue.submit_new(CmdDeleteDesign.TYPE, {"design": _design_id})
			_hull = ""
			_start_after_delete.call_deferred(), r)
	var code := LineEdit.new()
	code.name = "Code"
	code.placeholder_text = TranslationServer.translate("DESIGNER_CODE_HINT")
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(code)
	button(TranslationServer.translate("DESIGNER_EXPORT"), "Export", func() -> void:
		code.text = DesignCode.encode(_name, _hull, _components)
		DisplayServer.clipboard_set(code.text)
		_code_status = "DESIGNER_EXPORTED"
		rebuild.call_deferred(), r)
	button(TranslationServer.translate("DESIGNER_IMPORT"), "Import", func() -> void:
		var d := DesignCode.decode(code.text, state.defs, state.empire(eid).species)
		if not d["errors"].is_empty() or not d["missing_mods"].is_empty():
			_code_status = "DESIGNER_IMPORT_FAILED"
		else:
			_design_id = 0
			_hull = d["hull"]
			_components.assign(d["components"])
			_name = d["name"]
			_code_status = "DESIGNER_IMPORTED"
		rebuild.call_deferred(), r)
	if _code_status != "":
		line(TranslationServer.translate(_code_status), "Caption")


## Commands apply on the next sim step; then the newest own design is the one just saved.
func _pick_newest_after_save() -> void:
	await get_tree().create_timer(0.3).timeout
	var state := GameState.state
	var newest: ShipDesign = null
	for did: int in state.designs.ordered():
		var d: ShipDesign = state.designs.get_or(did)
		if d.owner == CommandQueue.local_player:
			newest = d
	if newest != null:
		_load_design(newest)
	rebuild()


func _start_after_delete() -> void:
	await get_tree().create_timer(0.3).timeout
	_start_from_first_design()
	rebuild()
