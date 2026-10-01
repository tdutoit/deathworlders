class_name Colonisation
extends RefCounted
## Colonisation and claims (Sub-spec B10 colony ship, B16, B17, D2, D9).
## A colony ship ordered to a planet flies there and lands: the planet becomes a Colony with the ship's pop.
## Claiming a new system costs influence: 25 x (1000 + owned_systems x 60) / 1000 (D9).

const INFLUENCE := "core:resource/influence"
const CREDITS := "core:resource/credits"
const FARM := "core:building/farm"


## Influence (milli) the next system claim costs this empire.
static func claim_cost_milli(state: MatchState, eid: int) -> int:
	var r := Economy.rules(state.defs)
	var owned := 0
	for sid: int in state.galaxy.systems:
		if state.galaxy.system(sid).owner == eid:
			owned += 1
	return FixedMath.floor_div(r.claim_influence_base * Stockpile.MILLI * (1000 + owned * r.claim_influence_per_system_permille), 1000)


static func can_pay_claim(state: MatchState, eid: int) -> String:
	var have: int = state.empire(eid).treasury.get(INFLUENCE, 0)
	var cost := claim_cost_milli(state, eid)
	if have >= cost:
		return ""
	return "claiming a system needs %d influence (you have %d)" % [FixedMath.floor_div(cost, 1000), FixedMath.floor_div(have, 1000)]


static func pay_claim(state: MatchState, eid: int) -> int:
	var cost := claim_cost_milli(state, eid)
	var e := state.empire(eid)
	e.treasury[INFLUENCE] = int(e.treasury.get(INFLUENCE, 0)) - cost
	return cost


static func check_colonise(state: MatchState, eid: int, unit_id: int, planet_id: int) -> String:
	var u: Unit = state.units.get_or(unit_id)
	if u == null or u.owner != eid or u.kind != "colony":
		return "unit %d is not your colony ship" % unit_id
	var planet := state.galaxy.planet(planet_id)
	if planet == null:
		return "unknown planet %d" % planet_id
	if state.colony(planet_id) != null:
		return "%s is already settled" % planet.name
	var ptype: PlanetTypeDef = state.defs.get_def(StringName(planet.planet_type))
	if ptype.orbital_only:
		return "%s can only host stations" % planet.name
	var species: SpeciesDef = state.defs.get_def(StringName(state.empire(eid).species))
	if int(species.habitability.get(StringName(planet.planet_type), 0)) <= 0:
		return "%s is uninhabitable for your species" % planet.name
	var owner := state.galaxy.system(planet.system_id).owner
	if owner != StateIO.NONE and owner != eid:
		return "the system belongs to another empire"
	if Pathfinder.route(state.galaxy, u.system_id, planet.system_id).is_empty() and u.system_id != planet.system_id:
		return "no route to %s" % planet.name
	return can_pay_claim(state, eid) if owner == StateIO.NONE else ""


## Order the ship (rules already checked); an unclaimed system is claimed and paid for now.
static func order(state: MatchState, u: Unit, planet_id: int) -> void:
	var sys := state.galaxy.system(state.galaxy.planet(planet_id).system_id)
	if sys.owner == StateIO.NONE:
		pay_claim(state, u.owner)
		sys.owner = u.owner
	u.target_planet = planet_id


## Hourly, after Movement: colony ships fly to their target system and land.
static func tick(state: MatchState) -> void:
	for uid: int in state.units.keys():
		var u: Unit = state.units.get_or(uid)
		if u.kind != "colony" or u.target_planet == StateIO.NONE or u.is_moving():
			continue
		var planet := state.galaxy.planet(u.target_planet)
		if u.system_id != planet.system_id:
			u.path = Pathfinder.route(state.galaxy, u.system_id, planet.system_id)
			u.progress = 0
			continue
		if state.colony(planet.id) != null:  # someone settled first: wait for new orders
			u.target_planet = StateIO.NONE
			continue
		_land(state, u, planet)


static func _land(state: MatchState, u: Unit, planet: Planet) -> void:
	var hull: HullDef = state.defs.get_def(StringName(u.hull_id))
	var c := Colony.new()
	c.id = planet.id
	c.owner = u.owner
	c.pops = {state.empire(u.owner).species: maxi(1, hull.pop_cost)}
	c.founded_tick = state.tick
	c.stage = "colony"
	planet.owner = u.owner
	state.colonies.put(c.id, c)
	Economy.assign_jobs(c, state.defs)
	state.units.erase(u.id)
	Sectors.update_membership(state)


## New colonies (D9): upkeep credits until their first Farm is built.
static func young_colony_upkeep_milli(state: MatchState, c: Colony) -> int:
	if FARM in c.buildings:
		return 0
	return Economy.rules(state.defs).new_colony_upkeep_credits * Stockpile.MILLI


## B17: extra growth permille for colonies younger than new_colony_growth_years.
static func young_growth_permille(state: MatchState, c: Colony) -> int:
	var r := Economy.rules(state.defs)
	return r.new_colony_growth_permille if state.tick - c.founded_tick < r.new_colony_growth_years * Calendar.HOURS_PER_YEAR else 0


## Rough payback estimate for the colonise screen (D9), in months: the colony ship's value in credits over
## the colony's expected monthly value at full housing (taxes + one job's base output value per pop) minus
## its early upkeep. M2 placeholder, tuned in WP14. -1 = never.
static func payback_months(state: MatchState, eid: int, planet_id: int) -> int:
	var hull: HullDef = state.defs.get_def(&"core:hull/colony_ship")
	var cost := 0
	for res: StringName in hull.cost:
		cost += int(hull.cost[res]) * (state.defs.get_def(res) as ResourceDef).base_value
	var planet := state.galaxy.planet(planet_id)
	var size: PlanetSizeDef = state.defs.get_def(PlanetSizeDef.id_for(planet.size))
	var species: SpeciesDef = state.defs.get_def(StringName(state.empire(eid).species))
	var pops := FixedMath.mul_permille(size.housing, int(species.habitability.get(StringName(planet.planet_type), 0)))
	var r := Economy.rules(state.defs)
	var monthly := pops * (r.tax_per_pop_milli + 4000) - r.new_colony_upkeep_credits * 1000  # ~4 credits of output per pop
	return -1 if monthly <= 0 else FixedMath.floor_div(cost + monthly - 1, monthly)
