class_name BuildRules
extends RefCounted
## What may be built where (Sub-spec B10, main spec 5, B change log 2026-10-01). Each check returns a
## readable reason, or "" when allowed. Queued items count as if already built.


static func pace(state: MatchState) -> int:
	var p := state.defs.get_def(StringName(state.settings.pace)) as MatchPresetDef
	return p.pace_permille if p else 1000


## A new Construction for a Def at the match pace.
static func new_construction(state: MatchState, kind: String, def_id: String, cost: Dictionary, days: int) -> Construction:
	var c := Construction.new()
	c.kind = kind
	c.def_id = def_id
	for res: StringName in IdMap.sort_keys(cost.keys()):
		c.cost[String(res)] = Pace.scale(int(cost[res]), pace(state)) * Stockpile.MILLI
	c.total_days = maxi(1, Pace.scale(days, pace(state)))
	return c


static func check_building(state: MatchState, empire: int, planet_id: int, building_id: String) -> String:
	var db := state.defs
	var b := db.get_def(StringName(building_id)) as BuildingDef
	if b == null:
		return "unknown building %s" % building_id
	var c := state.colony(planet_id)
	if c == null or c.owner != empire:
		return "planet %d is not your colony" % planet_id
	if not b.buildable:
		return "%s cannot be built" % building_id
	var planned: Array[String] = c.buildings.duplicate()
	for q in c.queue:
		planned.append(q.def_id)
	var planet := state.galaxy.planet(planet_id)
	if b.uses_slot:
		var used := 0
		for id in planned:
			if (db.get_def(StringName(id)) as BuildingDef).uses_slot:
				used += 1
		if used >= Economy.slots(c, planet, db):
			return "no free building slot"
	if b.unique and building_id in planned:
		return "only one %s per planet" % building_id
	if b.requires_focus != &"" and StringName(c.primary_focus) != b.requires_focus:
		return "needs %s as Primary focus" % b.requires_focus
	if b.requires_deposit != &"":
		var richness: int = planet.deposits.get(String(b.requires_deposit), 0)
		if planned.count(building_id) >= richness:
			return "needs a %s deposit (richness %d allows %d)" % [b.requires_deposit, richness, richness]
	if b.requires_system_planet_type != &"":
		var found := false
		for pid in state.galaxy.system(planet.system_id).planet_ids:
			if state.galaxy.planet(pid).planet_type == String(b.requires_system_planet_type):
				found = true
		if not found:
			return "needs a %s in the system" % b.requires_system_planet_type
	return ""


## Stations: a free orbital slot on the body, a matching placement and deposit. Outposts may be built in
## unclaimed systems (claim on completion, WP8 adds the influence cost); everything else needs the system.
static func check_station(state: MatchState, empire: int, planet_id: int, station_id: String) -> String:
	var db := state.defs
	var def := db.get_def(StringName(station_id)) as StationDef
	if def == null:
		return "unknown station %s" % station_id
	if def.tier != 1:
		return "build tier 1 and upgrade it"
	var planet := state.galaxy.planet(planet_id)
	if planet == null:
		return "unknown planet %d" % planet_id
	var system := state.galaxy.system(planet.system_id)
	if def.function == &"outpost":
		if system.owner != StateIO.NONE:
			return "system already claimed"
		var pay := Colonisation.can_pay_claim(state, empire)
		if pay != "":
			return pay
	elif system.owner != empire:
		return "the system is not yours"
	if stations_at(state, planet_id).size() >= planet.orbital_slots:
		return "no free orbital slot at %s" % planet.name
	if not def.placement.is_empty() and not StringName(planet.planet_type) in def.placement:
		return "%s can't orbit a %s" % [station_id, planet.planet_type]
	if def.requires_deposit != &"" and int(planet.deposits.get(String(def.requires_deposit), 0)) <= 0:
		return "needs a %s deposit" % def.requires_deposit
	return ""


static func check_upgrade(state: MatchState, empire: int, station_id: int) -> String:
	var s := state.station(station_id)
	if s == null or s.owner != empire:
		return "station %d is not yours" % station_id
	if not s.operational or s.build != null:
		return "the station is busy"
	var def: StationDef = state.defs.get_def(StringName(s.def_id))
	if def.upgrades_to == &"":
		return "already at the top tier"
	return ""


## Stations (built or building) around a body, in ID order.
static func stations_at(state: MatchState, planet_id: int) -> Array[Station]:
	var out: Array[Station] = []
	for sid: int in state.stations.ordered():
		var s: Station = state.stations.get_or(sid)
		if s.planet_id == planet_id:
			out.append(s)
	return out
