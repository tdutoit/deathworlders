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
	if hull.pop_cost > 0 and pop_source(state, s, hull.pop_cost) == null:
		return "a colony ship needs a colony in this system with %d pops to spare" % hull.pop_cost
	return ""


## Queues a ship (rules already checked). Local shipyard build speed shortens the build (B4).
static func queue_ship(state: MatchState, s: Station, hull_id: String) -> void:
	var hull: HullDef = state.defs.get_def(StringName(hull_id))
	var b := BuildRules.new_construction(state, "ship", hull_id, hull.cost, hull.build_days)
	var speed := build_speed_permille(state, s)
	b.total_days = maxi(1, FixedMath.floor_div(b.total_days * 1000 + 999 + speed, 1000 + speed))  # ceil
	s.ship_queue.append(b)


## shipyard.build_speed from the own colony the shipyard orbits (Industrial focus: +100 permille).
static func build_speed_permille(state: MatchState, s: Station) -> int:
	var c := state.colony(s.planet_id)
	if c == null or c.owner != s.owner:
		return 0
	return PlanetMods.of(c, state.defs).permille("shipyard.build_speed")


static func day_tick(state: MatchState) -> void:
	for sid: int in state.stations:
		var s: Station = state.stations.get_or(sid)
		if s.ship_queue.is_empty() or not s.operational or Builder._halted(state, s.owner):
			continue
		var def: StationDef = state.defs.get_def(StringName(s.def_id))
		var i := 0
		var active := 0
		while i < s.ship_queue.size() and active < def.docks:
			var b := s.ship_queue[i]
			active += 1
			if Builder._advance(b, s.stockpile) and _launch(state, s, b):
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
	spawn(state, s.owner, b.def_id, s.system_id)
	return true


## A new ship unit at a system; freighters get a berth at a hub there if one is free.
static func spawn(state: MatchState, owner: int, hull_id: String, system_id: int) -> Unit:
	var hull: HullDef = state.defs.get_def(StringName(hull_id))
	var u := Unit.new()
	u.id = state.alloc_id()
	u.owner = owner
	u.kind = String(hull.role)
	u.hull_id = hull_id
	u.system_id = system_id
	u.speed = FixedMath.floor_div(hull.lane_speed * Movement.MILLI, Calendar.HOURS_PER_DAY)
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
		return PlanetMods.of(c, state.defs).resolve("planet.freighter_berths", 0)
	return 0


static func berths_used(state: MatchState, hub_id: int) -> int:
	var n := 0
	for uid: int in state.units:
		if (state.units.get_or(uid) as Unit).home == hub_id:
			n += 1
	return n


## A hub in the system with a free berth (stations first, then colonies, by ID), or NONE.
static func free_berth(state: MatchState, owner: int, system_id: int) -> int:
	var candidates: Array[int] = []
	for sid: int in state.stations:
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
	for uid: int in state.units:
		var u: Unit = state.units.get_or(uid)
		var hull := state.defs.get_def(StringName(u.hull_id)) as HullDef if u.hull_id != "" else null
		if hull == null:
			continue
		var credits: int = hull.upkeep.get(&"core:resource/credits", 0)
		if credits > 0:
			due[u.owner] = due.get(u.owner, 0) + credits * Stockpile.MILLI
	return due
