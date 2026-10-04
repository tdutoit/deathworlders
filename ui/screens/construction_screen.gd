class_name ConstructionScreen
extends ScreenPanel
## Construction screen (M4 WP15; F4 buildings and orbitals, F12 "Shipyard idle [Queue]"): one planet's
## building queue, its orbitals and its shipyard queues, with what can be added now. Only options the
## sim would accept are offered (its reasons are log text, not loc keys); slot counts explain most blocks.
## Everything goes through Commands.

var planet_id := 0


func _init() -> void:
	title_key = "BUILD_TITLE"


func open_for(pid: int) -> void:
	planet_id = pid
	open()


func _fill(state: MatchState, eid: int) -> void:
	var p := state.galaxy.planet(planet_id)
	if p == null:
		return
	line(UiKit.tr_fmt("BUILD_PLANET", {"name": p.name, "system": state.galaxy.system(p.system_id).name}), "Subtitle")
	var c := state.colony(planet_id)
	if c != null and c.owner == eid:
		_buildings(state, eid, c, p)
	_orbitals(state, eid, p)


# --- planet buildings ---

func _buildings(state: MatchState, eid: int, c: Colony, p: Planet) -> void:
	var db := state.defs
	var used := 0
	for b in c.buildings:
		if (db.get_def(StringName(b)) as BuildingDef).uses_slot:
			used += 1
	heading("BUILD_BUILDINGS", {"n": used, "max": Economy.slots(c, p, db)})
	if c.autonomy == "automated":
		line(TranslationServer.translate("BUILD_AUTOMATED"), "Caption")
	for i in c.queue.size():
		var q: Construction = c.queue[i]
		var r := row()
		line(_progress(q, i == 0), "", r).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i > 0:
			button(TranslationServer.translate("BUILD_UP"), "BUp_%d" % i, func() -> void:
				CommandQueue.submit_new(CmdMoveConstruction.TYPE, {"planet": c.id, "index": i, "to": i - 1}), r)
		button(TranslationServer.translate("BUILD_CANCEL"), "BCancel_%d" % i, func() -> void:
			CommandQueue.submit_new(CmdCancelConstruction.TYPE, {"planet": c.id, "index": i}), r)
	line(TranslationServer.translate("BUILD_ADD_BUILDING"), "Caption")
	var options := _flow()
	var any := false
	for def in db.defs("building"):
		var b: BuildingDef = def
		if BuildRules.check_building(state, eid, c.id, String(b.id)) != "":
			continue
		any = true
		var id := String(b.id)
		button(UiKit.tr_fmt("BUILD_ADD", {"name": TranslationServer.translate(b.name_key), "cost": _cost(state, b.cost, b.build_days)}),
			"BAdd_" + id.get_slice("/", 1), func() -> void:
				CommandQueue.submit_new(CmdQueueBuilding.TYPE, {"planet": c.id, "building": id}), options)
	if not any:
		line(TranslationServer.translate("BUILD_NO_BUILDINGS"), "Caption", options)


# --- orbitals ---

func _orbitals(state: MatchState, eid: int, p: Planet) -> void:
	var db := state.defs
	var here := BuildRules.stations_at(state, p.id)
	heading("BUILD_ORBITALS", {"n": here.size(), "max": p.orbital_slots})
	for s in here:
		var def: StationDef = db.get_def(StringName(s.def_id))
		var r := row()
		var text := TranslationServer.translate(def.name_key)
		if s.build != null:
			text += "  " + UiKit.tr_fmt("BUILD_STATION_PROGRESS", {"name": UiNames.def_name(s.build.def_id),
				"done": s.build.days_done, "total": s.build.total_days})
		if s.owner != eid:
			text += "  (" + UiNames.owner(state, s.owner) + ")"
		line(text, "", r).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if s.owner != eid:
			continue
		if BuildRules.check_upgrade(state, eid, s.id) == "":
			var next: StationDef = db.get_def(def.upgrades_to)
			button(UiKit.tr_fmt("BUILD_UPGRADE", {"name": TranslationServer.translate(next.name_key), "cost": _cost(state, next.cost, next.build_days)}),
				"SUpgrade_%d" % s.id, func() -> void: CommandQueue.submit_new(CmdUpgradeStation.TYPE, {"station": s.id}), r)
		if s.build != null:
			button(TranslationServer.translate("BUILD_CANCEL"), "SCancel_%d" % s.id, func() -> void:
				CommandQueue.submit_new(CmdCancelConstruction.TYPE, {"station": s.id}), r)
		if s.operational and def.function == &"shipyard":
			_shipyard(state, eid, s, def)
	line(TranslationServer.translate("BUILD_ADD_STATION"), "Caption")
	var options := _flow()
	var any := false
	for d in db.defs("station"):
		var sd: StationDef = d
		if BuildRules.check_station(state, eid, p.id, String(sd.id)) != "":
			continue
		any = true
		var id := String(sd.id)
		button(UiKit.tr_fmt("BUILD_ADD", {"name": TranslationServer.translate(sd.name_key), "cost": _cost(state, sd.cost, sd.build_days)}),
			"SAdd_" + id.get_slice("/", 1), func() -> void:
				CommandQueue.submit_new(CmdQueueStation.TYPE, {"planet": p.id, "station": id}), options)
	if not any:
		line(TranslationServer.translate("BUILD_NO_STATIONS"), "Caption", options)


func _shipyard(state: MatchState, eid: int, s: Station, def: StationDef) -> void:
	var db := state.defs
	line("   " + UiKit.tr_fmt("BUILD_SHIPYARD", {"size": String(def.shipyard_size), "docks": def.docks}), "Caption")
	for i in s.ship_queue.size():
		var q: Construction = s.ship_queue[i]
		var r := row()
		var label := UiNames.def_name(q.def_id)
		var d: ShipDesign = state.designs.get_or(q.design) if q.design != 0 else null
		if d != null:
			label = TranslationServer.translate(d.name)
		line("   " + _progress(q, i < def.docks, label), "", r).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i > 0:
			button(TranslationServer.translate("BUILD_UP"), "YUp_%d_%d" % [s.id, i], func() -> void:
				CommandQueue.submit_new(CmdMoveConstruction.TYPE, {"station": s.id, "ship_index": i, "to": i - 1}), r)
		button(TranslationServer.translate("BUILD_CANCEL"), "YCancel_%d_%d" % [s.id, i], func() -> void:
			CommandQueue.submit_new(CmdCancelConstruction.TYPE, {"station": s.id, "ship_index": i}), r)
	line("   " + TranslationServer.translate("BUILD_ADD_SHIP"), "Caption")
	var civ := _flow()
	for def_h in db.defs("hull"):
		var h: HullDef = def_h
		var id := String(h.id)
		if not h.role in Shipyards.CIVILIAN_ROLES or Shipyards.check_ship(state, eid, s.id, id) != "":
			continue
		button(UiKit.tr_fmt("BUILD_ADD", {"name": TranslationServer.translate(h.name_key), "cost": _cost(state, h.cost, h.build_days)}),
			"YHull_%d_%s" % [s.id, id.get_slice("/", 1)], func() -> void:
				CommandQueue.submit_new(CmdQueueShip.TYPE, {"station": s.id, "hull": id}), civ)
	line("   " + TranslationServer.translate("BUILD_ADD_WARSHIP"), "Caption")
	var war := _flow()
	var any := false
	for did: int in state.designs.ordered():
		var d: ShipDesign = state.designs.get_or(did)
		if d.owner != eid or Shipyards.check_design_ship(state, eid, s.id, did) != "":
			continue
		any = true
		var h: HullDef = db.get_def(StringName(d.hull))
		button(UiKit.tr_fmt("BUILD_ADD", {"name": TranslationServer.translate(d.name), "cost": _cost(state, ShipStats.cost(db, d.hull, d.components), h.build_days)}),
			"YDesign_%d_%d" % [s.id, did], func() -> void:
				CommandQueue.submit_new(CmdQueueShip.TYPE, {"station": s.id, "design": did}), war)
	if not any:
		line(TranslationServer.translate("BUILD_NO_DESIGNS"), "Caption", war)


## A row of option buttons that wraps to the panel width.
func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(f)
	return f


# --- text ---

## "Name  12/90 days" for the item being worked on, "Name  queued" otherwise; stalls flagged.
func _progress(q: Construction, active: bool, label := "") -> String:
	var text := label if label != "" else UiNames.def_name(q.def_id)
	if active:
		text += "  " + UiKit.tr_fmt("BUILD_DAYS", {"done": q.days_done, "total": q.total_days})
		if q.stalled_days > 0:
			text += "  " + UiKit.tr_fmt("BUILD_STALLED", {"n": q.stalled_days})
	else:
		text += "  " + TranslationServer.translate("BUILD_QUEUED")
	return text


## "Alloys 80, Components 20 · 90 d" at the match pace (what the queued Construction will need).
static func _cost(state: MatchState, cost: Dictionary, days: int) -> String:
	var pace := BuildRules.pace(state)
	var parts := []
	for res: Variant in IdMap.sort_keys(cost.keys()):
		parts.append("%s %d" % [UiNames.def_name(String(res)), Pace.scale(int(cost[res]), pace)])
	return UiKit.tr_fmt("BUILD_COST", {"items": ", ".join(parts), "days": Pace.scale(days, pace)})
