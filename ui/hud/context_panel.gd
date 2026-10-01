class_name ContextPanel
extends PanelContainer
## Details of the selected cluster, system, planet or unit (F4/F5, M1 subset). Read-only.

var _box: VBoxContainer
var _kind := ""
var _id := 0


func _ready() -> void:
	theme_type_variation = "Glass"
	custom_minimum_size.x = 300
	_box = VBoxContainer.new()
	add_child(_box)
	EventBus.selection_changed.connect(show_selection)
	show_selection("", 0)


func show_selection(kind: String, id: int) -> void:
	_kind = kind
	_id = id
	_rebuild()


## Units move, so their lines refresh every hour tick.
func _process(_delta: float) -> void:
	if _kind == "unit" and GameState.state and Engine.get_process_frames() % 15 == 0:
		_rebuild()


func _rebuild() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.free()
	var state := GameState.state
	if state == null or _kind == "" or _id == 0:
		_line("CTX_NOTHING", "Caption")
		return
	var g := state.galaxy
	match _kind:
		"cluster":
			var c := g.cluster(_id)
			_line("CTX_CLUSTER", "Caption")
			_text(c.name, "Subtitle")
			_line("CTX_SYSTEMS", "", {"n": c.system_ids.size()})
		"system":
			var s := g.system(_id)
			_line("CTX_SYSTEM", "Caption")
			_text(s.name, "Subtitle")
			_line("CTX_STAR", "", {"name": _def_name(s.star_type)})
			_line("CTX_IN_CLUSTER", "", {"name": g.cluster(s.cluster_id).name})
			_line("CTX_PLANETS", "", {"n": s.planet_ids.size()})
			_owner_line(s.owner)
		"planet":
			var p := g.planet(_id)
			_line("CTX_PLANET", "Caption")
			_text(p.name, "Subtitle")
			if _is_capital(p.id):
				_line("CTX_CAPITAL", "Caption")
			_line("CTX_TYPE", "", {"name": _def_name(p.planet_type)})
			_line("CTX_SIZE", "", {"name": TranslationServer.translate("SIZE_" + p.size.to_upper())})
			_line("CTX_IN_SYSTEM", "", {"name": g.system(p.system_id).name})
			_line("CTX_SLOTS", "", {"n": p.orbital_slots})
			_owner_line(p.owner)
			_line("CTX_DEPOSITS", "Caption")
			if p.deposits.is_empty():
				_line("CTX_NO_DEPOSITS")
			for res: String in IdMap.sort_keys(p.deposits.keys()):
				_text("%s  %s" % [_def_name(res), "●".repeat(int(p.deposits[res]))])
		"unit":
			var u: Unit = state.units.get_or(_id)
			if u == null:
				_line("CTX_NOTHING", "Caption")
				return
			_line("CTX_UNIT", "Caption")
			_text(TranslationServer.translate("UNIT_" + u.kind.to_upper()), "Subtitle")
			_owner_line(u.owner)
			_line("CTX_AT", "", {"name": g.system(u.system_id).name})
			if u.is_moving():
				_line("CTX_DEST", "", {"name": g.system(u.path[-1]).name})
				_line("CTX_ETA", "", {"n": _eta_days(state, u)})
			else:
				_line("CTX_IDLE")
			if u.owner == CommandQueue.local_player:
				_line("CTX_ORDER_HINT", "Caption")


func _line(key: String, variation := "", params := {}) -> void:
	var l := UiKit.label(key, variation, params)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(l)


func _text(text: String, variation := "") -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	_box.add_child(l)


func _owner_line(owner: int) -> void:
	if owner == StateIO.NONE:
		_line("CTX_UNCLAIMED")
		return
	var e: Empire = GameState.state.empires.get_or(owner)
	_line("CTX_OWNER", "", {"name": _def_name(e.species)})


static func _def_name(id: String) -> String:
	var def := Database.defs.get_def(StringName(id))
	return TranslationServer.translate(def.name_key) if def else id


func _is_capital(planet_id: int) -> bool:
	for eid: int in GameState.state.empires:
		if (GameState.state.empires.get_or(eid) as Empire).capital_planet == planet_id:
			return true
	return false


## Remaining lane distance / speed, in days (rounded up).
static func _eta_days(state: MatchState, u: Unit) -> int:
	var at := u.system_id
	var remaining := -u.progress
	for next in u.path:
		remaining += state.galaxy.lane_between(at, next).length * Movement.MILLI
		at = next
	var hours := ceili(float(remaining) / maxi(u.speed, 1))
	return ceili(hours / float(Calendar.HOURS_PER_DAY))
