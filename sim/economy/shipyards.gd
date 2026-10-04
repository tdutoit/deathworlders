class_name Shipyards
extends RefCounted
## Shipyards and civilian ships (Sub-spec B6, B10): parallel builds per dock, ship upkeep, freighter berths.

const CIVILIAN_ROLES: Array[StringName] = [&"freighter", &"colony", &"scout"]  # M2: warships come with M3


static func check_ship(state: MatchState, empire_id: int, station_id: int, hull_id: String) -> String:
	var s := state.station(station_id)
	if s == null or s.owner != empire_id:
		return "station %d is not yours" % station_id
	var def: StationDef = state.defs.get_def(StringName(s.def_id))
	if not s.operational or def.function != &"shipyard":
		return "not an operational shipyard"
	var hull := state.defs.get_def(StringName(hull_id)) as HullDef
	if hull == null:
		return "unknown hull %s" % hull_id
	if not hull.role in CIVILIAN_ROLES:
		return "warships arrive with M3"
	var e := state.empire(empire_id)
	if hull.species != &"" and String(hull.species) != e.species:
		return "%s is a %s hull" % [hull_id, hull.species]
	var tech := Research.missing(state, empire_id, hull.requires_tech)  # M5
	if tech != "":
		return tech
	if hull.pop_cost > 0 and pop_source(state, s, hull.pop_cost) == null:
		return "a colony ship needs a colony in this system with %d pops to spare" % hull.pop_cost
	return ""


## "" if this empire may build one of its designs at that shipyard (M3), else the reason. Shipyard size
## gates the hull (B10: S up to destroyers, M up to battlecruisers and carriers, L all).
static func check_design_ship(state: MatchState, empire_id: int, station_id: int, design_id: int) -> String:
	var s := state.station(station_id)
	if s == null or s.owner != empire_id:
		return "station %d is not yours" % station_id
	var def: StationDef = state.defs.get_def(StringName(s.def_id))
	if not s.operational or def.function != &"shipyard":
		return "not an operational shipyard"
	var d := Designs.owned(state, empire_id, design_id)
	if d == null:
		return "design %d is not yours" % design_id
	var hull := state.defs.get_def(StringName(d.hull)) as HullDef
	if hull == null:
		return "unknown hull %s" % d.hull
	if HullDef.YARD_SIZES.find(String(def.shipyard_size)) < HullDef.YARD_SIZES.find(String(hull.shipyard_size)):
		return "a %s hull needs a size %s shipyard" % [hull.hull_class, hull.shipyard_size]
	var tech := design_tech(state, empire_id, d)  # M5: a design can be saved before its techs, not built
	if tech != "":
		return tech
	return Wars.check_disarmament(state, empire_id, Wars._cost_value(state, ShipStats.cost(state.defs, d.hull, d.components)))  # E7


## Queues a ship of one of the empire's designs (rules already checked). The construction keeps a copy of
## the design's components, so later edits don't change it.
static func queue_design(state: MatchState, s: Station, design_id: int) -> void:
	var d: ShipDesign = state.designs.get_or(design_id)
	var hull: HullDef = state.defs.get_def(StringName(d.hull))
	var cost := {}
	var whole := ShipStats.cost(state.defs, d.hull, d.components)
	for res: String in whole:
		cost[StringName(res)] = whole[res]
	var b := BuildRules.new_construction(state, "ship", d.hull, cost, hull.build_days)
	b.design = design_id
	b.components = d.components.duplicate()
	_apply_build_speed(state, s, b)
	s.ship_queue.append(b)


## Queues a ship (rules already checked). Local shipyard build speed shortens the build (B4).
static func queue_ship(state: MatchState, s: Station, hull_id: String) -> void:
	var hull: HullDef = state.defs.get_def(StringName(hull_id))
	var b := BuildRules.new_construction(state, "ship", hull_id, hull.cost, hull.build_days)
	_apply_build_speed(state, s, b)
	s.ship_queue.append(b)


static func _apply_build_speed(state: MatchState, s: Station, b: Construction) -> void:
	var speed := build_speed_permille(state, s)
	b.total_days = maxi(1, FixedMath.floor_div(b.total_days * 1000 + 999 + speed, 1000 + speed))  # ceil


## shipyard.build_speed from the own colony the shipyard orbits (Industrial focus: +100 permille).
static func build_speed_permille(state: MatchState, s: Station) -> int:
	var c := state.colony(s.planet_id)
	if c == null or c.owner != s.owner:
		return 0
	return PlanetMods.of(state, c).permille("shipyard.build_speed")


static func day_tick(state: MatchState) -> void:
	for sid: int in state.stations.ordered():
		var s: Station = state.stations.get_or(sid)
		if s.ship_queue.is_empty() or not s.operational or Builder._halted(state, s.owner):
			continue
		var def: StationDef = state.defs.get_def(StringName(s.def_id))
		var i := 0
		var active := 0
		while i < s.ship_queue.size() and active < def.docks:
			var b := s.ship_queue[i]
			active += 1
			if Builder._advance(b, s.stockpile, Builder.orbit_supply(state, s)) and _launch(state, s, b):
				s.ship_queue.remove_at(i)
			else:
				i += 1


## Creates the finished ship. Returns false (and holds the dock) if a colony ship can't take its pop yet.
static func _launch(state: MatchState, s: Station, b: Construction) -> bool:
	var hull: HullDef = state.defs.get_def(StringName(b.def_id))
	if hull.pop_cost > 0:
		var src := pop_source(state, s, hull.pop_cost)
		if src == null:
			b.days_done = b.total_days  # finished, waiting for a pop
			return false
		_take_pops(src, hull.pop_cost, state.defs)
	var u := spawn(state, s.owner, b.def_id, s.system_id, s.planet_id)
	u.design = b.design
	u.components = b.components.duplicate()
	if u.kind == "warship":
		Fleets.commission(state, u)
	return true


## A new ship unit at a system (at `at_body`, or its first body); freighters get a berth at a hub there.
static func spawn(state: MatchState, owner: int, hull_id: String, system_id: int, at_body: int = StateIO.NONE) -> Unit:
	var hull: HullDef = state.defs.get_def(StringName(hull_id))
	var u := Unit.new()
	u.id = state.alloc_id()
	u.owner = owner
	u.kind = String(hull.role)
	u.hull_id = hull_id
	u.system_id = system_id
	u.speed = FixedMath.floor_div(hull.lane_speed * Movement.MILLI, Calendar.HOURS_PER_DAY)
	u.body = at_body if at_body != StateIO.NONE else state.galaxy.system(system_id).planet_ids[0]
	state.units.put(u.id, u)
	if hull.role == &"freighter":
		u.home = free_berth(state, owner, system_id)
	return u


## An own colony in the station's system with more than `pops` pops (the orbited body first).
static func pop_source(state: MatchState, s: Station, pops: int) -> Colony:
	var orbited := state.colony(s.planet_id)
	if orbited != null and orbited.owner == s.owner and orbited.total_pops() > pops:
		return orbited
	for pid in state.galaxy.system(s.system_id).planet_ids:
		var c := state.colony(pid)
		if c != null and c.owner == s.owner and c.total_pops() > pops:
			return c
	return null


static func _take_pops(c: Colony, n: int, db: DefDatabase) -> void:
	for i in n:
		Economy._remove_pop(c)
	Economy.assign_jobs(c, db)


# --- berths (B6) ---

## Berths a hub offers: a Logistics station's tier berths, or a colony's planet.freighter_berths
## (Logistics focus +4, Dockworkers +2 each).
static func berths(state: MatchState, hub_id: int) -> int:
	var s := state.station(hub_id)
	if s != null:
		return (state.defs.get_def(StringName(s.def_id)) as StationDef).berths if s.operational else 0
	var c := state.colony(hub_id)
	if c != null:
		return PlanetMods.of(state, c).resolve("planet.freighter_berths", 0)
	return 0


static func berths_used(state: MatchState, hub_id: int) -> int:
	var n := 0
	for uid: int in state.units.ordered():
		if (state.units.get_or(uid) as Unit).home == hub_id:
			n += 1
	return n


## A hub in the system with a free berth (stations first, then colonies, by ID), or NONE.
static func free_berth(state: MatchState, owner: int, system_id: int) -> int:
	var candidates: Array[int] = []
	for sid: int in state.stations.ordered():
		var s: Station = state.stations.get_or(sid)
		if s.owner == owner and s.system_id == system_id:
			candidates.append(sid)
	for pid in state.galaxy.system(system_id).planet_ids:
		var c := state.colony(pid)
		if c != null and c.owner == owner:
			candidates.append(pid)
	for hub in candidates:
		if berths_used(state, hub) < berths(state, hub):
			return hub
	return StateIO.NONE


static func check_rebase(state: MatchState, empire_id: int, unit_id: int, hub_id: int) -> String:
	var u: Unit = state.units.get_or(unit_id)
	if u == null or u.owner != empire_id or u.kind != "freighter":
		return "unit %d is not your freighter" % unit_id
	var hub_owner := -1
	if state.station(hub_id) != null:
		hub_owner = state.station(hub_id).owner
	elif state.colony(hub_id) != null:
		hub_owner = state.colony(hub_id).owner
	if hub_owner != empire_id:
		return "hub %d is not yours" % hub_id
	if u.home == hub_id:
		return "already based there"
	if berths_used(state, hub_id) >= berths(state, hub_id):
		return "no free berth at hub %d" % hub_id
	return ""


## Monthly credits upkeep of ships per owner (milli-credits), from hull upkeep.
static func upkeep(state: MatchState) -> Dictionary:
	var due := {}
	for uid: int in state.units.ordered():
		var u: Unit = state.units.get_or(uid)
		var hull := state.defs.get_def(StringName(u.hull_id)) as HullDef if u.hull_id != "" else null
		if hull == null:
			continue
		var credits: int = hull.credit_upkeep_milli if hull.credit_upkeep_milli > 0 \
				else int(hull.upkeep.get(&"core:resource/credits", 0)) * Stockpile.MILLI  # B10 ships, B6 freighters
		if credits > 0:
			due[u.owner] = due.get(u.owner, 0) + credits
	return due


## The first tech a design's hull or components still need ("" = buildable by research), M5.
static func design_tech(state: MatchState, empire_id: int, d: ShipDesign) -> String:
	var hull := state.defs.get_def(StringName(d.hull)) as HullDef
	var why := Research.missing(state, empire_id, hull.requires_tech) if hull != null else ""
	if why != "":
		return why
	for cid: Variant in d.components:
		var c := state.defs.get_def(StringName(cid)) as ComponentDef if String(cid) != "" else null
		if c != null:
			why = Research.missing(state, empire_id, c.requires_tech)
			if why != "":
				return why
	return ""
