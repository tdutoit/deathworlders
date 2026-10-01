class_name Builder
extends RefCounted
## Daily construction progress (Sub-spec B10): each colony's first queued building and every station
## build take today's share of materials from the site stockpile; if anything is missing the day stalls
## (nothing is lost). Owners in credit deficit build nothing (B13).


static func day_tick(state: MatchState) -> void:
	for pid: int in state.colonies:
		var c: Colony = state.colonies.get_or(pid)
		if c.queue.is_empty() or _halted(state, c.owner):
			continue
		if _advance(c.queue[0], c.stockpile):
			c.buildings.append(c.queue[0].def_id)
			c.queue.remove_at(0)
			Economy.assign_jobs(c, state.defs)
	for sid: int in state.stations:
		var s: Station = state.stations.get_or(sid)
		if s.build == null or _halted(state, s.owner):
			continue
		if _advance(s.build, s.stockpile):
			_finish_station(state, s)


## One day of work. Returns true when the build completes.
static func _advance(b: Construction, site: Stockpile) -> bool:
	var need := b.today_need()
	for res: String in need:
		if site.milli(res) < need[res]:
			b.stalled_days += 1
			return false
	for res: String in need:
		site.take(res, need[res])
	b.stalled_days = 0
	b.days_done += 1
	return b.is_done()


static func _finish_station(state: MatchState, s: Station) -> void:
	s.def_id = s.build.def_id
	s.build = null
	if not s.operational:
		s.operational = true
		var def: StationDef = state.defs.get_def(StringName(s.def_id))
		if def.function == &"outpost":  # claims the system (D2)
			state.galaxy.system(s.system_id).owner = s.owner


static func _halted(state: MatchState, empire_id: int) -> bool:
	var e := state.empire(empire_id)
	return e != null and e.deficit_months > 0


## Queues a building on a colony (rules already checked).
static func queue_building(state: MatchState, c: Colony, building_id: String) -> void:
	var b: BuildingDef = state.defs.get_def(StringName(building_id))
	c.queue.append(BuildRules.new_construction(state, "building", building_id, b.cost, b.build_days))


## Creates a station construction site (rules already checked); returns it.
static func place_station(state: MatchState, empire_id: int, planet_id: int, station_id: String) -> Station:
	var def: StationDef = state.defs.get_def(StringName(station_id))
	var s := Station.new()
	s.id = state.alloc_id()
	s.owner = empire_id
	s.def_id = station_id
	s.planet_id = planet_id
	s.system_id = state.galaxy.planet(planet_id).system_id
	s.build = BuildRules.new_construction(state, "station", station_id, def.cost, def.build_days)
	state.stations.put(s.id, s)
	return s


## Starts the upgrade to the next tier (rules already checked).
static func start_upgrade(state: MatchState, s: Station) -> void:
	var def: StationDef = state.defs.get_def(StringName(s.def_id))
	var next: StationDef = state.defs.get_def(def.upgrades_to)
	s.build = BuildRules.new_construction(state, "upgrade", String(next.id), next.cost, next.build_days)


## Cancels a build; materials already used go back to the site stockpile. A new station site disappears
## (its stockpile goes with it, so cancel it only when it's empty or you accept the loss).
static func cancel(state: MatchState, c: Colony, s: Station, index: int) -> void:
	if c != null:
		var q := c.queue[index]
		for res: String in q.paid():
			c.stockpile.add(res, q.paid()[res])
		c.queue.remove_at(index)
	elif s != null:
		for res: String in s.build.paid():
			s.stockpile.add(res, s.build.paid()[res])
		s.build = null
		if not s.operational:
			state.stations.erase(s.id)
