class_name Holders
extends RefCounted
## Stockpile holders: colonies (keyed by planet ID) and stations (station ID) share one ID space, so freight
## can address either. Also in-system travel times (Sub-spec B7).

const ORBIT_DAYS := 1  # B7: a body and its own orbit (stations, moons)
const MIN_DAYS := 2  # B7: planet to planet 2-8 days by distance
const MAX_DAYS := 8
const RADIUS_PER_DAY := 20  # orbit-radius units per extra day (Sol: Earth-Mars 3, Earth-Belt 4)


static func stockpile(state: MatchState, id: int) -> Stockpile:
	var c := state.colony(id)
	if c != null:
		return c.stockpile
	var s := state.station(id)
	return s.stockpile if s != null else null


static func owner(state: MatchState, id: int) -> int:
	var c := state.colony(id)
	if c != null:
		return c.owner
	var s := state.station(id)
	return s.owner if s != null else StateIO.NONE


## The body (planet ID) the holder sits at.
static func body(state: MatchState, id: int) -> int:
	if state.colony(id) != null:
		return id
	var s := state.station(id)
	return s.planet_id if s != null else StateIO.NONE


static func system(state: MatchState, id: int) -> int:
	var b := body(state, id)
	return state.galaxy.planet(b).system_id if b != StateIO.NONE else StateIO.NONE


## Stockpile cap for a resource in milli-units; 0 = uncapped. `mods_cache` (optional): colony ID ->
## PlanetMods, for callers that ask about many resources of the same colonies in one pass.
static func cap_milli(state: MatchState, id: int, res: String, mods_cache: Variant = null) -> int:
	var c := state.colony(id)
	if c != null:
		var mods: PlanetMods
		if mods_cache != null and (mods_cache as Dictionary).has(id):
			mods = mods_cache[id]
		else:
			mods = PlanetMods.of(c, state.defs)
			if mods_cache != null:
				mods_cache[id] = mods
		return Economy.cap_milli(c, state.defs, mods, res)
	var s := state.station(id)
	return StationOps.cap_milli(state, s, res) if s != null else 0


## Space left for a resource in milli-units; -1 = uncapped.
static func space_milli(state: MatchState, id: int, res: String) -> int:
	var cap := 0
	var c := state.colony(id)
	if c != null:
		cap = Economy.cap_milli(c, state.defs, PlanetMods.of(c, state.defs), res)
	else:
		var s := state.station(id)
		if s == null:
			return 0
		cap = StationOps.cap_milli(state, s, res)
	if cap <= 0:
		return -1
	return maxi(0, cap - stockpile(state, id).milli(res))


## Impulse days between two bodies in the same system (B7). Moons and stations count as their parent body.
static func impulse_days(state: MatchState, from_body: int, to_body: int) -> int:
	if from_body == to_body:
		return 0
	var a := state.galaxy.planet(from_body)
	var b := state.galaxy.planet(to_body)
	if a.parent_id == b.id or b.parent_id == a.id or (a.parent_id != 0 and a.parent_id == b.parent_id):
		return ORBIT_DAYS
	var ra := state.galaxy.planet(a.parent_id).orbit_radius if a.parent_id != 0 else a.orbit_radius
	var rb := state.galaxy.planet(b.parent_id).orbit_radius if b.parent_id != 0 else b.orbit_radius
	@warning_ignore("integer_division")
	return clampi(MIN_DAYS + absi(ra - rb) / RADIUS_PER_DAY, MIN_DAYS, MAX_DAYS)
