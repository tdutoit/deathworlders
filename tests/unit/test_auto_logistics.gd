extends GutTest
# M2 WP6: auto-logistics and demand targets (Sub-spec B8).

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
	s.sectors.clear()  # these tests check B8 alone; sector governors add their own demands (WP7b)
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


func _belts(s: MatchState) -> Array[Station]:
	return BuildRules.stations_at(s, _body(s, "Asteroid Belt").id)


func _days(s: MatchState, n: int) -> void:
	var none: Array[Command] = []
	for i in n * Calendar.HOURS_PER_DAY:
		Sim.step(s, none)


func _do(s: MatchState, type_id: StringName, payload: Dictionary) -> Command:
	var cmd := CommandRegistry.create(type_id, _human(s).id, payload)
	Sim.execute(s, [cmd] as Array[Command])
	return cmd


## Earth sits on the same body as the hub, so it is the nearest ore source; reserve all of it so the
## belt is the only source in these tests.
func _belt_only(s: MatchState) -> void:
	s.reserves["%d:%s" % [_human(s).capital_planet, ORE]] = 500


func _jobs(s: MatchState) -> Array:
	return s.units.values().filter(func(u: Unit) -> bool: return not u.job.is_empty())


func test_demand_target_is_filled_from_surplus() -> void:
	var s := _match()
	_belt_only(s)
	for b in _belts(s):
		b.stockpile.add(ORE, 150000)
	assert_eq(_do(s, CmdSetDemandTarget.TYPE, {"holder": _hub(s).id, "resource": ORE, "target": 100, "priority": 2}).error, "")
	_days(s, 1)
	assert_eq(_jobs(s).size(), 1, "one Light freighter covers a 100 deficit")
	var job: Dictionary = (_jobs(s)[0] as Unit).job
	assert_eq([job["dest"], job["amount"]], [_hub(s).id, 100000])
	_days(s, 11)
	assert_eq(_hub(s).stockpile.units(ORE), 100)
	assert_eq(_jobs(s).size(), 0, "demand met: nothing more is sent")


func test_reserve_is_left_alone() -> void:
	var s := _match()
	_belt_only(s)
	var belts := _belts(s)
	for b in belts:
		b.stockpile.take(ORE, b.stockpile.milli(ORE))
	belts[0].stockpile.add(ORE, 70000)  # reserve is 20% of 200 = 40
	_do(s, CmdSetDemandTarget.TYPE, {"holder": _hub(s).id, "resource": ORE, "target": 100, "priority": 2})
	_days(s, 1)
	assert_eq((_jobs(s)[0] as Unit).job["amount"], 30500, "only what is above the 40 reserve: 70 + the day's 0.5 mined - 40")
	assert_eq(_do(s, CmdSetReserve.TYPE, {"holder": belts[0].id, "resource": ORE, "units": 0}).error, "")
	assert_eq(AutoLogistics.reserve_milli(s, belts[0].id, ORE), 0)


func test_construction_site_feeds_itself() -> void:
	var s := _match()
	var mercury := _body(s, "Mercury")
	assert_eq(_do(s, CmdQueueStation.TYPE, {"planet": mercury.id, "station": "core:station/mining_moon"}).error, "")
	var site: Station = BuildRules.stations_at(s, mercury.id)[0]
	_days(s, 1)
	assert_eq(_jobs(s).size(), 1, "the site's 100 alloys are demanded automatically")
	assert_eq((_jobs(s)[0] as Unit).job["source"], _human(s).capital_planet, "Earth has the nearest alloy surplus")
	_days(s, 75)
	assert_true(site.operational, "delivered and built without a manual route")


func test_in_transit_counts_against_the_deficit() -> void:
	var s := _match()
	_belt_only(s)
	for b in _belts(s):
		b.stockpile.add(ORE, 150000)
	_do(s, CmdSetDemandTarget.TYPE, {"holder": _hub(s).id, "resource": ORE, "target": 100, "priority": 2})
	_days(s, 3)
	assert_eq(_jobs(s).size(), 1, "the first trip is still under way: no second freighter for the same 100")


func test_priority_order() -> void:
	var s := _match()
	for b in _belts(s):
		b.stockpile.add(ORE, 150000)
	var freighters := s.units.values().filter(func(u: Unit) -> bool: return u.kind == "freighter")
	for i in range(1, freighters.size()):
		(freighters[i] as Unit).home = StateIO.NONE  # leave one freighter on duty
	var earth := _human(s).capital_planet
	_do(s, CmdSetDemandTarget.TYPE, {"holder": _hub(s).id, "resource": ORE, "target": 100, "priority": 1})
	_do(s, CmdSetDemandTarget.TYPE, {"holder": earth, "resource": ORE, "target": 400, "priority": 3})
	_days(s, 1)
	assert_eq((_jobs(s)[0] as Unit).job["dest"], earth, "the Critical demand goes first")


func test_hub_range_limits_service() -> void:
	var s := _match()
	var home_sys := _hub(s).system_id
	var hops := AutoLogistics._hops_from(s, home_sys, {})
	var far := -1
	for sid: int in hops:
		if hops[sid] >= 4:
			far = sid
			break
	var c := Colony.new()
	c.id = s.galaxy.system(far).planet_ids[0]
	c.owner = _human(s).id
	s.colonies.put(c.id, c)
	_do(s, CmdSetDemandTarget.TYPE, {"holder": c.id, "resource": ALLOYS, "target": 50, "priority": 3})
	_days(s, 2)
	assert_eq(_jobs(s).size(), 0, "a T1 hub serves 3 lanes; this colony is %d away" % hops[far])


func test_remove_demand() -> void:
	var s := _match()
	_do(s, CmdSetDemandTarget.TYPE, {"holder": _hub(s).id, "resource": ORE, "target": 100, "priority": 2})
	assert_eq(s.demands.size(), 1)
	_do(s, CmdSetDemandTarget.TYPE, {"holder": _hub(s).id, "resource": ORE, "target": 0, "priority": 2})
	assert_eq(s.demands.size(), 0)
	assert_string_contains(_do(s, CmdSetDemandTarget.TYPE, {"holder": _hub(s).id, "resource": "core:resource/credits", "target": 5}).error, "physical")
