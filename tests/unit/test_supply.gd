extends GutTest
# M2 WP9: fuel and supply (Sub-spec B6 upkeep, B12 supply range).

const FUEL := "core:resource/fuel"

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func _match() -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	var errors: Array[String] = []
	return GalaxyGenerator.new_match(settings, 3, _db, errors)


func _human(s: MatchState) -> Empire:
	return s.empires.values()[0]


func _earth(s: MatchState) -> Colony:
	return s.colony(_human(s).capital_planet)


func _freighters(s: MatchState) -> Array:
	return s.units.values().filter(func(u: Unit) -> bool: return u.kind == "freighter")


func test_freighters_burn_earths_fuel() -> void:
	var s := _match()
	var before := _earth(s).stockpile.milli(FUEL)
	Supply.month_tick(s)
	assert_eq(before - _earth(s).stockpile.milli(FUEL), 3000, "3 Light freighters x 1 fuel (B6)")
	for f: Unit in _freighters(s):
		assert_false(f.out_of_fuel)


func test_out_of_fuel_halves_speed() -> void:
	var s := _match()
	_earth(s).stockpile.take(FUEL, _earth(s).stockpile.milli(FUEL))
	Supply.month_tick(s)
	var f: Unit = _freighters(s)[0]
	assert_true(f.out_of_fuel)
	var home := s.galaxy.system(f.system_id)
	f.path = [s.galaxy.lane(home.lane_ids[0]).other_end(home.id)] as Array[int]
	f.progress = 0
	Movement.tick(s)
	assert_eq(f.progress, 125, "half of 250 per hour")
	_earth(s).stockpile.add(FUEL, 10000)
	Supply.month_tick(s)
	assert_false(f.out_of_fuel, "resupplied")


func test_supply_range() -> void:
	var s := _match()
	var f: Unit = _freighters(s)[0]
	var hops := AutoLogistics._hops_from(s, f.system_id, {})
	for sid: int in IdMap.sort_keys(hops.keys()):
		if hops[sid] == 2:
			f.system_id = sid
			break
	Supply.month_tick(s)
	assert_true(f.out_of_fuel, "an owned planet only supplies 1 lane out")
	StartSetup._place_built(s, _human(s).id, _earth(s).id, "core:station/depot_t1")
	var depot: Station = BuildRules.stations_at(s, _earth(s).id)[-1]
	depot.stockpile.add(FUEL, 50000)
	Supply.month_tick(s)
	assert_false(f.out_of_fuel, "a T1 supply depot reaches 2 lanes")
	assert_eq(depot.stockpile.milli(FUEL), 49000)
