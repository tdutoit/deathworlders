class_name StartSetup
extends RefCounted
## Gives every empire's capital its opening economy from a StartDef (Sub-spec B19), in empire ID order.

const DEFAULT_START := &"core:start/default"


static func apply(state: MatchState, db: DefDatabase) -> void:
	var start: StartDef = db.get_def(DEFAULT_START)
	if start == null:
		return
	for eid: int in state.empires.ordered():
		var e: Empire = state.empires.get_or(eid)
		var planet := state.galaxy.planet(e.capital_planet)
		var c := Colony.new()
		c.id = planet.id
		c.owner = e.id
		c.pops = {e.species: start.pops}
		for b in start.buildings:
			c.buildings.append(String(b))
			_ensure_deposit(planet, db.get_def(b) as BuildingDef, start.buildings.count(b))
		c.primary_focus = String(start.primary_focus)
		c.secondary_focus = String(start.secondary_focus)
		for job: StringName in start.job_caps:
			c.job_caps[String(job)] = int(start.job_caps[job])
		for res: StringName in IdMap.sort_keys(start.stockpile.keys()):
			c.stockpile.add(String(res), int(start.stockpile[res]) * Stockpile.MILLI)
		for res: StringName in IdMap.sort_keys(start.treasury.keys()):
			e.treasury[String(res)] = e.treasury.get(String(res), 0) + int(start.treasury[res]) * Stockpile.MILLI
		c.stage = String(start.stage)
		Designs.give_standard(state, e.id)  # M3: the species' standard warship designs
		# Homeworlds are established worlds: past the young-colony bonus (B17) and Developed's age rule (D2).
		var r := Economy.rules(db)
		c.founded_tick = state.tick - maxi(r.new_colony_growth_years, r.developed_years) * Calendar.HOURS_PER_YEAR
		Economy.assign_jobs(c, db)
		state.colonies.put(c.id, c)
		for st in start.capital_stations:
			_place_built(state, e.id, planet.id, String(st))
		if not start.belt_stations.is_empty():
			var belt := _belt_of(state, planet)
			for st in start.belt_stations:
				_place_built(state, e.id, belt.id, String(st))
		# The capital anchors the Core Sector (D3); its logistics station keeps the sector stockpile (D5).
		var core_hub := planet.id
		for st in BuildRules.stations_at(state, planet.id):
			if (db.get_def(StringName(st.def_id)) as StationDef).function == &"logistics":
				core_hub = st.id
				break
		Sectors.create(state, e.id, core_hub, true)
		for hull in start.ships:
			Shipyards.spawn(state, e.id, String(hull), planet.system_id, planet.id)


## A finished station in orbit of a body (start only: no construction).
static func _place_built(state: MatchState, empire_id: int, planet_id: int, station_id: String) -> void:
	var s := Station.new()
	s.id = state.alloc_id()
	s.owner = empire_id
	s.def_id = station_id
	s.planet_id = planet_id
	s.system_id = state.galaxy.planet(planet_id).system_id
	s.operational = true
	state.stations.put(s.id, s)


## The home system's asteroid belt; one is added (outermost orbit) if the system has none, so every
## start has B19's belt income.
static func _belt_of(state: MatchState, capital: Planet) -> Planet:
	var sys := state.galaxy.system(capital.system_id)
	var outer := 0
	for pid in sys.planet_ids:
		var p := state.galaxy.planet(pid)
		if p.planet_type == "core:planet_type/asteroid_belt":
			return p
		outer = maxi(outer, p.orbit_radius)
	var belt := Planet.new()
	belt.id = state.alloc_id()
	belt.system_id = sys.id
	belt.name = NameGenerator.planet_name(sys.name, sys.planet_ids.size())
	belt.planet_type = "core:planet_type/asteroid_belt"
	belt.size = "medium"
	belt.orbit_index = sys.planet_ids.size()
	belt.orbit_radius = outer + 30
	belt.deposits = {"core:resource/ore": 3}
	belt.orbital_slots = (state.defs.get_def(PlanetSizeDef.id_for("medium")) as PlanetSizeDef).orbital_slots
	state.galaxy.planets.put(belt.id, belt)
	sys.planet_ids.append(belt.id)
	return belt


## A start building that needs a deposit gets one rich enough to hold all its copies.
static func _ensure_deposit(planet: Planet, b: BuildingDef, copies: int) -> void:
	if b == null or b.requires_deposit == &"":
		return
	var res := String(b.requires_deposit)
	planet.deposits[res] = maxi(int(planet.deposits.get(res, 0)), copies)
