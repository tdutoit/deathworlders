extends GutTest
# M2 WP4: shipyards and civilian ships (Sub-spec B6, B10, B19).

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
	return GalaxyGenerator.new_match(settings, 3, _db, errors)


func _human(s: MatchState) -> Empire:
	return s.empires.values()[0]


func _earth_stations(s: MatchState) -> Array[Station]:
	return BuildRules.stations_at(s, _human(s).capital_planet)


func _hub(s: MatchState) -> Station:
	return _earth_stations(s)[0]


func _yard(s: MatchState) -> Station:
	return _earth_stations(s)[1]


func _days(s: MatchState, n: int) -> void:
	var none: Array[Command] = []
	for i in n * Calendar.HOURS_PER_DAY:
		Sim.step(s, none)


func _do(s: MatchState, type_id: StringName, payload: Dictionary) -> Command:
	var cmd := CommandRegistry.create(type_id, _human(s).id, payload)
	Sim.execute(s, [cmd] as Array[Command])
	return cmd


func _of_kind(s: MatchState, kind: String) -> Array:
	return s.units.values().filter(func(u: Unit) -> bool: return u.kind == kind)


func test_starting_fleet() -> void:
	var s := _match()
	var freighters := _of_kind(s, "freighter")
	assert_eq(freighters.size(), 3)
	for f: Unit in freighters:
		assert_eq(f.home, _hub(s).id, "based at the Earth logistics station")
		assert_eq(f.speed, 250, "6 lane units/day = 250 milli per hour")
	assert_eq(_of_kind(s, "scout").size(), 1)
	assert_eq(_of_kind(s, "colony").size(), 1)
	assert_eq(s.colony(_human(s).capital_planet).total_pops(), 24, "starting ships don't cost pops")


func test_build_a_freighter() -> void:
	var s := _match()
	var yard := _yard(s)
	assert_eq(_do(s, CmdQueueShip.TYPE, {"station": yard.id, "hull": "core:hull/freighter_light"}).error, "")
	assert_eq(yard.ship_queue[0].total_days, 28, "30 days at +10% Industrial build speed, rounded up")
	yard.stockpile.add(ALLOYS, 40000)
	_days(s, 27)
	assert_eq(_of_kind(s, "freighter").size(), 3)
	_days(s, 1)
	var freighters := _of_kind(s, "freighter")
	assert_eq(freighters.size(), 4)
	assert_eq((freighters[-1] as Unit).home, _hub(s).id, "a free berth at the hub")


func test_one_dock_builds_one_ship_at_a_time() -> void:
	var s := _match()
	var yard := _yard(s)
	for i in 2:
		_do(s, CmdQueueShip.TYPE, {"station": yard.id, "hull": "core:hull/freighter_light"})
	yard.stockpile.add(ALLOYS, 80000)
	_days(s, 28)
	assert_eq(_of_kind(s, "freighter").size(), 4)
	assert_eq(yard.ship_queue.size(), 1)
	assert_eq(yard.ship_queue[0].days_done, 0, "the second waited for the dock")
	_days(s, 28)
	assert_eq(_of_kind(s, "freighter").size(), 5)


func test_no_free_berth_means_idle() -> void:
	var s := _match()
	for i in 3:  # fill the hub's 6 berths
		Shipyards.spawn(s, _human(s).id, "core:hull/freighter_light", _hub(s).system_id)
	var extra := Shipyards.spawn(s, _human(s).id, "core:hull/freighter_light", _hub(s).system_id)
	assert_eq(extra.home, StateIO.NONE)
	var earth := s.colony(_human(s).capital_planet)
	assert_string_contains(_do(s, CmdRebaseFreighter.TYPE, {"unit": extra.id, "hub": earth.id}).error, "no free berth")
	earth.primary_focus = "core:focus/logistics"  # +4 berths (B6)
	assert_eq(Shipyards.berths(s, earth.id), 4)
	assert_eq(_do(s, CmdRebaseFreighter.TYPE, {"unit": extra.id, "hub": earth.id}).error, "")
	assert_eq(extra.home, earth.id)


func test_colony_ship_takes_a_pop() -> void:
	var s := _match()
	var yard := _yard(s)
	assert_eq(_do(s, CmdQueueShip.TYPE, {"station": yard.id, "hull": "core:hull/colony_ship"}).error, "")
	for res: String in ["alloys", "components", "food"]:
		yard.stockpile.add("core:resource/" + res, 200000)
	_days(s, yard.ship_queue[0].total_days)
	assert_eq(_of_kind(s, "colony").size(), 2)
	assert_eq(s.colony(_human(s).capital_planet).total_pops(), 23)


func test_ship_rules() -> void:
	var s := _match()
	assert_string_contains(_do(s, CmdQueueShip.TYPE, {"station": _yard(s).id, "hull": "core:hull/human_corvette_mk1"}).error, "M3")
	assert_string_contains(_do(s, CmdQueueShip.TYPE, {"station": _hub(s).id, "hull": "core:hull/freighter_light"}).error, "shipyard")
	assert_string_contains(_do(s, CmdQueueShip.TYPE, {"station": _yard(s).id, "hull": "core:hull/nope"}).error, "unknown hull")


func test_cancel_ship_refunds() -> void:
	var s := _match()
	var yard := _yard(s)
	_do(s, CmdQueueShip.TYPE, {"station": yard.id, "hull": "core:hull/freighter_light"})
	yard.stockpile.add(ALLOYS, 40000)
	_days(s, 14)
	assert_eq(_do(s, CmdCancelConstruction.TYPE, {"station": yard.id, "ship_index": 0}).error, "")
	assert_eq(yard.stockpile.milli(ALLOYS), 40000, "everything back: used + unused")
	assert_true(yard.ship_queue.is_empty())


func test_freighter_upkeep_is_charged() -> void:
	var s := _match()
	assert_eq(Shipyards.upkeep(s)[_human(s).id], 3000, "3 light freighters x 1 credit")
