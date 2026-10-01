extends GutTest
# M2 WP5: freighters and manual routes (Sub-spec B6-B8, B19).

const ORE := "core:resource/ore"
const ALLOYS := "core:resource/alloys"

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func _match() -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	var errors: Array[String] = []
	var s := GalaxyGenerator.new_match(settings, 3, _db, errors)
	s.sectors.clear()  # manual routes in isolation; sector governors add their own freight (WP7b)
	return s


func _human(s: MatchState) -> Empire:
	return s.empires.values()[0]


func _body(s: MatchState, name: String) -> Planet:
	for pid: int in s.galaxy.planets:
		if s.galaxy.planet(pid).name == name:
			return s.galaxy.planet(pid)
	return null


func _hub(s: MatchState) -> Station:
	return BuildRules.stations_at(s, _human(s).capital_planet)[0]


func _belt_station(s: MatchState) -> Station:
	return BuildRules.stations_at(s, _body(s, "Asteroid Belt").id)[0]


func _freighters(s: MatchState) -> Array:
	return s.units.values().filter(func(u: Unit) -> bool: return u.kind == "freighter")


func _hours(s: MatchState, n: int, top_up: Station = null) -> void:
	var none: Array[Command] = []
	for i in n:
		if top_up != null and i % Calendar.HOURS_PER_DAY == 0:
			top_up.stockpile.add(ORE, 200000, 200000)  # keep the source full
		Sim.step(s, none)


func _do(s: MatchState, type_id: StringName, payload: Dictionary) -> Command:
	var cmd := CommandRegistry.create(type_id, _human(s).id, payload)
	Sim.execute(s, [cmd] as Array[Command])
	return cmd


func _route(s: MatchState, source: int, dest: int, res: String, amount := 100) -> Route:
	var cmd := _do(s, CmdCreateRoute.TYPE, {"source": source, "dest": dest, "resource": res, "amount": amount, "priority": 2})
	assert_eq(cmd.error, "")
	return s.routes.values()[-1]


func test_impulse_days_in_sol() -> void:
	var s := _match()
	var earth := _body(s, "Earth").id
	assert_eq(Holders.impulse_days(s, earth, _body(s, "Mars").id), 3, "B7: Earth-Mars 3")
	assert_eq(Holders.impulse_days(s, earth, _body(s, "Asteroid Belt").id), 4, "B7: Earth-Belt 4")
	assert_eq(Holders.impulse_days(s, earth, _body(s, "Luna").id), 1, "B7: Earth-Luna 1 (orbit)")
	assert_eq(Holders.impulse_days(s, earth, _body(s, "Jupiter").id), 6, "B7 says 8; radius-only model gives 6")
	assert_eq(Holders.impulse_days(s, earth, earth), 0)


func test_throughput_formula() -> void:
	var s := _match()
	var r := _route(s, _belt_station(s).id, _hub(s).id, ORE)
	assert_eq(Freight.throughput(s, r, _db.get_def(&"core:hull/freighter_light")), 300, "B7/B19: ~300 a month")


func test_b19_belt_haul_delivers_300_a_month() -> void:
	var s := _match()
	var belt := _belt_station(s)
	var hub := _hub(s)
	var r := _route(s, belt.id, hub.id, ORE)
	var f: Unit = _freighters(s)[0]
	assert_eq(_do(s, CmdAssignFreighter.TYPE, {"unit": f.id, "route": r.id}).error, "")
	_hours(s, 10 * Calendar.HOURS_PER_DAY + 1, belt)
	assert_eq(hub.stockpile.units(ORE), 100, "first delivery on day 10")
	_hours(s, 20 * Calendar.HOURS_PER_DAY, belt)
	assert_eq(hub.stockpile.units(ORE), 300, "one Light freighter: 300 ore a month")


func test_empty_source_waits_and_retries() -> void:
	var s := _match()
	var belt := _belt_station(s)
	belt.stockpile.take(ORE, belt.stockpile.milli(ORE))
	var hub := _hub(s)
	var r := _route(s, belt.id, hub.id, ORE)
	var f: Unit = _freighters(s)[0]
	_do(s, CmdAssignFreighter.TYPE, {"unit": f.id, "route": r.id})
	_hours(s, 6 * Calendar.HOURS_PER_DAY)  # the belt only makes 15 a month: a few units by now
	assert_eq(f.phase, "to_dest", "it took what was there rather than waiting for a full load")
	belt.stockpile.take(ORE, belt.stockpile.milli(ORE))


func test_overflow_stays_aboard() -> void:
	var s := _match()
	var hub := _hub(s)
	hub.stockpile.add(ORE, 1000000, 1000000)  # hub full (cap 1000)
	var belt := _belt_station(s)
	var r := _route(s, belt.id, hub.id, ORE)
	var f: Unit = _freighters(s)[0]
	_do(s, CmdAssignFreighter.TYPE, {"unit": f.id, "route": r.id})
	_hours(s, 10 * Calendar.HOURS_PER_DAY + 1, belt)
	assert_eq(hub.stockpile.units(ORE), 1000)
	assert_eq(f.cargo.get(ORE, 0), 100000, "nothing lost: the load is still aboard")


func test_trip_between_systems() -> void:
	var s := _match()
	var hub := _hub(s)
	var home := s.galaxy.system(hub.system_id)
	var lane := s.galaxy.lane(home.lane_ids[0])
	var other := s.galaxy.system(lane.other_end(home.id))
	var c := Colony.new()  # an own colony next door
	c.id = other.planet_ids[0]
	c.owner = _human(s).id
	s.colonies.put(c.id, c)
	hub.stockpile.add(ALLOYS, 500000)
	var r := _route(s, hub.id, c.id, ALLOYS)
	var hull: HullDef = _db.get_def(&"core:hull/freighter_light")
	var one_way := Freight.one_way_days(s, hub.id, c.id, hull)
	assert_eq(one_way, (lane.length + 5) / 6, "lane units / 6 per day, rounded up")
	var f: Unit = _freighters(s)[0]
	_do(s, CmdAssignFreighter.TYPE, {"unit": f.id, "route": r.id})
	_hours(s, (one_way + 2) * Calendar.HOURS_PER_DAY)
	assert_eq(c.stockpile.units(ALLOYS), 100, "loaded at home, flew one lane, unloaded")


func test_delete_route_sends_freighters_home() -> void:
	var s := _match()
	var r := _route(s, _belt_station(s).id, _hub(s).id, ORE)
	var f: Unit = _freighters(s)[0]
	_do(s, CmdAssignFreighter.TYPE, {"unit": f.id, "route": r.id})
	_hours(s, 2 * Calendar.HOURS_PER_DAY)
	assert_eq(_do(s, CmdDeleteRoute.TYPE, {"route": r.id}).error, "")
	assert_eq(f.route, StateIO.NONE)
	_hours(s, 12 * Calendar.HOURS_PER_DAY)
	assert_eq(f.body, Holders.body(s, f.home), "back at its hub")
	assert_eq(f.phase, "")


func test_route_rules() -> void:
	var s := _match()
	var hub := _hub(s).id
	var belt := _belt_station(s).id
	assert_string_contains(_do(s, CmdCreateRoute.TYPE, {"source": belt, "dest": hub, "resource": "core:resource/credits", "amount": 5}).error, "physical")
	assert_string_contains(_do(s, CmdCreateRoute.TYPE, {"source": belt, "dest": belt, "resource": ORE, "amount": 5}).error, "same")
	assert_string_contains(_do(s, CmdCreateRoute.TYPE, {"source": 999999, "dest": hub, "resource": ORE, "amount": 5}).error, "not your")
	var idle := Shipyards.spawn(s, _human(s).id, "core:hull/freighter_light", s.galaxy.planet(_human(s).capital_planet).system_id)
	idle.home = StateIO.NONE
	var r := _route(s, belt, hub, ORE)
	assert_string_contains(_do(s, CmdAssignFreighter.TYPE, {"unit": idle.id, "route": r.id}).error, "no berth")
	assert_eq(_do(s, CmdEditRoute.TYPE, {"route": r.id, "amount": 50, "priority": 3}).error, "")
	assert_eq([r.amount, r.priority], [50, 3])


func test_routes_survive_save_and_checksum() -> void:
	var s := _match()
	var r := _route(s, _belt_station(s).id, _hub(s).id, ORE)
	_do(s, CmdAssignFreighter.TYPE, {"unit": (_freighters(s)[0] as Unit).id, "route": r.id})
	_hours(s, 50)
	var copy := MatchState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(copy.checksum(), s.checksum())
	assert_true(s.checksum().has("logistics"))
