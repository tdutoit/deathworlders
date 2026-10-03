class_name ContextPanel
extends PanelContainer
## Details of the selected cluster, system, planet or unit (F4/F5). Reads state; its buttons submit Commands.
## Planets with a colony show the F4 colony block (stage, focus, autonomy, pops, jobs, stockpile, buildings).

signal colonise_requested(planet_id: int)
signal fleet_requested(fleet_id: int)

const AUTONOMY: Array[String] = ["automated", "assisted", "manual"]
const STOCK_LINES := 6

var _scroll: ScrollContainer
var _box: VBoxContainer
var _kind := ""
var _id := 0
var _last_tick := -1


func _ready() -> void:
	theme_type_variation = "Glass"
	custom_minimum_size.x = 300
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)
	EventBus.selection_changed.connect(show_selection)
	show_selection("", 0)


func show_selection(kind: String, id: int) -> void:
	_kind = kind
	_id = id
	_rebuild()


## Units move, so their lines refresh often; planets (stockpiles, builds) once a sim day.
func _process(_delta: float) -> void:
	var state := GameState.state
	if state == null or Engine.get_process_frames() % 15 != 0:
		return
	if _kind == "unit" or (_kind == "planet" and state.tick / Calendar.HOURS_PER_DAY != _last_tick):
		_rebuild()


func _rebuild() -> void:
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focus_name := String(focused.name) if focused != null and is_ancestor_of(focused) else ""
	for c in _box.get_children():
		_box.remove_child(c)
		c.free()
	if GameState.state != null:
		_last_tick = GameState.state.tick / Calendar.HOURS_PER_DAY
	_fill()
	_fit_height.call_deferred()
	if focus_name != "":
		var again := _box.find_child(focus_name, true, false) as Control
		if again != null:
			again.grab_focus()


## After layout (wrapped labels know their width only then): as tall as the content, up to the screen bottom.
func _fit_height() -> void:
	if not is_inside_tree():
		return
	var room := get_viewport_rect().size.y - position.y - 60.0
	_scroll.custom_minimum_size.y = minf(_box.get_combined_minimum_size().y, maxf(room, 120.0))
	reset_size()


func _fill() -> void:
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
			var colony := state.colony(p.id)
			if colony != null:
				_colony_section(state, colony)
				if colony.owner == CommandQueue.local_player and BroodSurgeMechanic.check(state, colony.owner, colony.id) == "":
					_button("CTX_BROOD_SURGE", func() -> void: CommandQueue.submit_new(CmdBroodSurge.TYPE, {"colony": colony.id}))
			elif Colonisation.check_colonise(state, CommandQueue.local_player, idle_colony_ship(state, p.id), p.id) == "":
				_button("CTX_COLONISE", func() -> void: colonise_requested.emit(p.id))
			_stations_section(state, p.id)
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
			var f: Fleet = state.fleets.get_or(u.fleet) if u.fleet != StateIO.NONE else null
			if f != null:
				_fleet_section(state, f)
			elif u.owner == CommandQueue.local_player:
				_line("CTX_ORDER_HINT", "Caption")


## A warship's fleet (F5, compact): name, size and condition, status; own fleets link to the Fleets screen.
func _fleet_section(state: MatchState, f: Fleet) -> void:
	_line("CTX_FLEET", "Caption")
	_text(UiFleets.name_of(state, f), "Subtitle")
	var c := UiFleets.condition(state, f)
	_text(UiKit.tr_fmt("FLEET_SUMMARY", {"ships": f.size(), "str": UiKit.units(UiFleets.strength(state, f) * 1000),
		"hull": UiNames.bar(c[0], c[1]), "ammo": UiNames.bar(c[2], c[3]) if c[3] > 0 else "—",
		"supply": TranslationServer.translate("FLEET_SUPPLIED" if UiFleets.supplied(state, f) else "FLEET_UNSUPPLIED")}), "Mono")
	for i in f.task_forces.size():
		_text(UiKit.tr_fmt("FLEET_TF", {"n": i + 1, "ships": UiFleets.composition(state, f.task_forces[i])}))
	if f.owner == CommandQueue.local_player:
		_line("CTX_FLEET_HINT", "Caption")
		_button("FLEET_OPEN", func() -> void: fleet_requested.emit(f.id))


func _line(key: String, variation := "", params := {}) -> void:
	var l := UiKit.label(key, variation, params)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(l)


func _text(text: String, variation := "") -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(l)


## F4 colony block. Own colonies get the autonomy switch and the governor's plan.
func _colony_section(state: MatchState, c: Colony) -> void:
	var p := state.galaxy.planet(c.id)
	var db := state.defs
	_line("CTX_COLONY", "Caption")
	_line("CTX_STAGE", "", {"name": TranslationServer.translate("STAGE_" + c.stage.to_upper())})
	var focus: String = TranslationServer.translate("CTX_NONE") if c.primary_focus == "" else _def_name(c.primary_focus)
	if c.secondary_focus != "":
		focus += " ▸ " + _def_name(c.secondary_focus)
	_line("CTX_FOCUS", "", {"name": focus})
	_line("CTX_POPS", "", {"n": c.total_pops(), "max": Economy.housing(state, c, p, db), "stab": c.stability})
	if c.starving:
		_line("CTX_STARVING")
	var jobs := []
	for job: String in IdMap.sort_keys(c.jobs.keys()):
		jobs.append("%s %d" % [_def_name(job), int(c.jobs[job])])
	if c.unemployed() > 0:
		jobs.append(UiKit.tr_fmt("CTX_UNEMPLOYED", {"n": c.unemployed()}))
	_text(", ".join(jobs) if not jobs.is_empty() else TranslationServer.translate("CTX_NO_JOBS"))
	if c.owner != CommandQueue.local_player:
		return
	var row := HBoxContainer.new()
	for mode in AUTONOMY:
		var b := Button.new()
		b.name = "Autonomy_" + mode
		b.text = TranslationServer.translate("AUTONOMY_" + mode.to_upper())
		b.toggle_mode = true
		b.button_pressed = c.autonomy == mode
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(func() -> void:
			CommandQueue.submit_new(CmdSetAutonomy.TYPE, {"planet": c.id, "autonomy": mode}))
		row.add_child(b)
	_box.add_child(row)
	_line("CTX_STOCKPILE", "Caption")
	var shown := 0
	for res: String in IdMap.sort_keys(c.stockpile.amounts.keys()):
		if shown == STOCK_LINES:
			_line("CTX_MORE_IN_STOCKPILE", "Caption")
			break
		var cap := Holders.cap_milli(state, c.id, res)
		var net := int(c.last_produced.get(res, 0)) - int(c.last_consumed.get(res, 0))
		_text("%s  %s%s  %s" % [_def_name(res), UiKit.units(c.stockpile.milli(res)),
			(" / " + UiKit.units(cap)) if cap > 0 else "", UiKit.signed(net)], "Mono")
		shown += 1
	var used := 0
	for b in c.buildings:
		if (db.get_def(StringName(b)) as BuildingDef).uses_slot:
			used += 1
	_line("CTX_BUILDINGS", "Caption", {"n": used, "max": Economy.slots(c, p, db)})
	var counts := {}
	for b in c.buildings:
		counts[b] = counts.get(b, 0) + 1
	for b: String in IdMap.sort_keys(counts.keys()):
		_text("%s ×%d" % [_def_name(b), counts[b]])
	if not c.queue.is_empty():
		var q: Construction = c.queue[0]
		_line("CTX_BUILDING_NOW", "", {"name": _def_name(q.def_id), "done": q.days_done, "total": q.total_days})
		if q.stalled_days > 0:
			_line("CTX_STALLED", "Caption", {"n": q.stalled_days})
	if c.autonomy == "assisted" and c.suggestion != "":
		_line("CTX_SUGGESTS", "", {"name": _def_name(c.suggestion)})
		_button("CTX_APPROVE", func() -> void: CommandQueue.submit_new(CmdApproveSuggestion.TYPE, {"planet": c.id}))
	elif c.autonomy == "automated":
		var next := Governor.next_building(state, c)
		if next != "":
			_line("CTX_GOVERNOR_PLANS", "Caption", {"name": _def_name(next)})
	else:
		var next := Governor.next_building(state, c)
		if next != "":
			_button("CTX_QUEUE_NEXT", func() -> void:
				CommandQueue.submit_new(CmdQueueBuilding.TYPE, {"planet": c.id, "building": next}), {"name": _def_name(next)})


func _stations_section(state: MatchState, planet_id: int) -> void:
	var here := BuildRules.stations_at(state, planet_id)
	if here.is_empty():
		return
	_line("CTX_ORBITALS", "Caption")
	for s in here:
		var text := _def_name(s.def_id)
		if not s.operational and s.build != null:
			text += "  " + UiKit.tr_fmt("CTX_UNDER_CONSTRUCTION", {"done": s.build.days_done, "total": s.build.total_days})
		elif s.build != null:
			text += "  " + UiKit.tr_fmt("CTX_UPGRADING", {"done": s.build.days_done, "total": s.build.total_days})
		if s.owner != CommandQueue.local_player:
			text += "  (" + _owner_name(s.owner) + ")"
		_text(text)


## The local player's colony ship best placed to settle this planet: idle ones first, then lowest ID.
static func idle_colony_ship(state: MatchState, _planet_id: int) -> int:
	var best := 0
	for uid: int in state.units:
		var u: Unit = state.units.get_or(uid)
		if u.owner == CommandQueue.local_player and u.kind == "colony" and u.target_planet == StateIO.NONE:
			return u.id
		if u.owner == CommandQueue.local_player and u.kind == "colony" and best == 0:
			best = u.id
	return best


func _button(key: String, on_pressed: Callable, params := {}) -> void:
	var b := UiKit.button(key, on_pressed)
	b.name = key
	if not params.is_empty():
		b.text = UiKit.tr_fmt(key, params)
	_box.add_child(b)


static func _owner_name(owner: int) -> String:
	if owner == Pirates.PIRATES:
		return TranslationServer.translate("OWNER_PIRATES")
	var e: Empire = GameState.state.empires.get_or(owner)
	return _def_name(e.species) if e else "?"


func _owner_line(owner: int) -> void:
	if owner == StateIO.NONE:
		_line("CTX_UNCLAIMED")
		return
	if owner == Pirates.PIRATES:
		_line("CTX_OWNER", "", {"name": TranslationServer.translate("OWNER_PIRATES")})
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
