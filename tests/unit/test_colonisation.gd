extends GutTest
# M2 WP8: colonisation and claims (Sub-spec B10, B16, B17, D2, D9).

const INFLUENCE := "core:resource/influence"

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func _match() -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	settings.add_player(1, "core:species/krothi", "ai")
	var errors: Array[String] = []
	return GalaxyGenerator.new_match(settings, 3, _db, errors)


func _human(s: MatchState) -> Empire:
	return s.empires.values()[0]


func _body(s: MatchState, name: String) -> Planet:
	for pid: int in s.galaxy.planets:
		if s.galaxy.planet(pid).name == name:
			return s.galaxy.planet(pid)
	return null


func _ship(s: MatchState) -> Unit:
	for u: Unit in s.units.values():
		if u.kind == "colony" and u.owner == _human(s).id:
			return u
	return null


func _hours(s: MatchState, n: int) -> void:
	var none: Array[Command] = []
	for i in n:
		Sim.step(s, none)


func _do(s: MatchState, type_id: StringName, payload: Dictionary) -> Command:
	var cmd := CommandRegistry.create(type_id, _human(s).id, payload)
	Sim.execute(s, [cmd] as Array[Command])
	return cmd


func test_claim_cost_formula() -> void:
	var s := _match()
	assert_eq(Colonisation.claim_cost_milli(s, _human(s).id), 26500, "25 x (1000 + 1 x 60) / 1000 with Sol owned")


func test_settle_mars() -> void:
	var s := _match()
	var mars := _body(s, "Mars")
	var ship := _ship(s)
	assert_eq(_do(s, CmdColonise.TYPE, {"unit": ship.id, "planet": mars.id}).error, "")
	_hours(s, 2)
	var c := s.colony(mars.id)
	assert_not_null(c, "landed in the same system at once")
	assert_eq(c.total_pops(), 1)
	assert_eq(c.stage, "colony")
	assert_eq(mars.owner, _human(s).id)
	assert_null(s.units.get_or(ship.id), "the ship is used up")
	assert_eq(s.colony(_human(s).capital_planet).total_pops(), 24, "the starting ship carried its own pop")


func test_colonise_rules() -> void:
	var s := _match()
	var ship := _ship(s)
	assert_string_contains(_do(s, CmdColonise.TYPE, {"unit": ship.id, "planet": _body(s, "Jupiter").id}).error, "stations")
	assert_string_contains(_do(s, CmdColonise.TYPE, {"unit": ship.id, "planet": _human(s).capital_planet}).error, "settled")
	var krothi: Empire = s.empires.values()[1]
	var their_planet := s.galaxy.system(s.galaxy.planet(krothi.capital_planet).system_id).planet_ids
	var target := -1
	for pid in their_planet:
		if s.colony(pid) == null and not (_db.get_def(StringName(s.galaxy.planet(pid).planet_type)) as PlanetTypeDef).orbital_only:
			target = pid
	if target != -1:
		assert_string_contains(_do(s, CmdColonise.TYPE, {"unit": ship.id, "planet": target}).error, "another empire")


func test_unclaimed_system_costs_influence_and_needs_the_trip() -> void:
	var s := _match()
	var ship := _ship(s)
	var home := s.galaxy.planet(_human(s).capital_planet).system_id
	var hops := AutoLogistics._hops_from(s, home, {})
	var target := -1
	for sid: int in IdMap.sort_keys(hops.keys()):
		if hops[sid] == 1 and s.galaxy.system(sid).owner == StateIO.NONE:
			for pid in s.galaxy.system(sid).planet_ids:
				var p := s.galaxy.planet(pid)
				if not (_db.get_def(StringName(p.planet_type)) as PlanetTypeDef).orbital_only \
						and int((_db.get_def(&"core:species/human") as SpeciesDef).habitability.get(StringName(p.planet_type), 0)) > 0:
					target = pid
		if target != -1:
			break
	assert_ne(target, -1, "a habitable planet one lane away")
	assert_string_contains(_do(s, CmdColonise.TYPE, {"unit": ship.id, "planet": target}).error, "influence")
	_human(s).treasury[INFLUENCE] = 30000
	assert_eq(_do(s, CmdColonise.TYPE, {"unit": ship.id, "planet": target}).error, "")
	assert_eq(_human(s).treasury[INFLUENCE], 30000 - 26500)
	assert_eq(s.galaxy.system(s.galaxy.planet(target).system_id).owner, _human(s).id, "claimed when ordered")
	_hours(s, 3)
	assert_null(s.colony(target), "still on the way")
	_hours(s, 40 * Calendar.HOURS_PER_DAY)
	assert_not_null(s.colony(target), "arrived and settled")


func test_young_colony_upkeep_and_growth() -> void:
	var s := _match()
	_do(s, CmdColonise.TYPE, {"unit": _ship(s).id, "planet": _body(s, "Mars").id})
	_hours(s, 2)
	var c := s.colony(_body(s, "Mars").id)
	assert_eq(Colonisation.young_colony_upkeep_milli(s, c), 3000, "3 credits until its Farm (WP14)")
	assert_eq(Colonisation.young_growth_permille(s, c), 1000, "+100% growth for 5 years")
	c.buildings.append("core:building/farm")
	assert_eq(Colonisation.young_colony_upkeep_milli(s, c), 0)
	assert_eq(Colonisation.young_growth_permille(s, s.colony(_human(s).capital_planet)), 0, "homeworlds aren't young")


func test_cancelled_outpost_refunds_influence() -> void:
	var s := _match()
	_human(s).treasury[INFLUENCE] = 50000
	var target := -1
	for sid: int in s.galaxy.systems:
		if s.galaxy.system(sid).owner == StateIO.NONE:
			target = s.galaxy.system(sid).planet_ids[0]
			break
	assert_eq(_do(s, CmdQueueStation.TYPE, {"planet": target, "station": "core:station/outpost"}).error, "")
	assert_eq(_human(s).treasury[INFLUENCE], 50000 - 26500)
	var site: Station = BuildRules.stations_at(s, target)[0]
	assert_eq(_do(s, CmdCancelConstruction.TYPE, {"station": site.id}).error, "")
	assert_eq(_human(s).treasury[INFLUENCE], 50000)


func test_payback_estimate() -> void:
	var s := _match()
	var months := Colonisation.payback_months(s, _human(s).id, _body(s, "Mars").id)
	assert_gt(months, 0)
	assert_lt(months, 12 * 20, "D9 targets 5-10 years; the placeholder stays in range of that")
