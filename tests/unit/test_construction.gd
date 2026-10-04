extends GutTest
# M2 WP3: construction and stations (Sub-spec B10/B11, main spec 5).

const ALLOYS := "core:resource/alloys"
const ORE := "core:resource/ore"

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func _match(pace := "pace_standard") -> MatchState:
	var settings := MatchSettings.new()
	settings.pace = "core:match_preset/" + pace
	settings.add_player(0, "core:species/human", "human")
	var errors: Array[String] = []
	return GalaxyGenerator.new_match(settings, 3, _db, errors)


func _human(s: MatchState) -> Empire:
	return s.empires.values()[0]


func _earth(s: MatchState) -> Colony:
	return s.colony(_human(s).capital_planet)


func _body(s: MatchState, name: String) -> Planet:
	for pid: int in s.galaxy.planets:
		if s.galaxy.planet(pid).name == name:
			return s.galaxy.planet(pid)
	return null


func _days(s: MatchState, n: int) -> void:
	var none: Array[Command] = []
	for i in n * Calendar.HOURS_PER_DAY:
		Sim.step(s, none)


func _do(s: MatchState, type_id: StringName, payload: Dictionary) -> Command:
	var cmd := CommandRegistry.create(type_id, _human(s).id, payload)
	Sim.execute(s, [cmd] as Array[Command])
	return cmd


func test_start_orbitals() -> void:
	var s := _match()
	var at_earth := BuildRules.stations_at(s, _earth(s).id)
	assert_eq(at_earth.map(func(st: Station) -> String: return st.def_id),
		["core:station/logistics_t1", "core:station/shipyard_t1"])
	var belt := BuildRules.stations_at(s, _body(s, "Asteroid Belt").id)
	assert_eq(belt.size(), 3)
	_days(s, 30)
	for st in belt:
		assert_eq(st.stockpile.units(ORE), 15, "B11: 15 ore a month per belt station")


func test_building_takes_its_days_and_materials() -> void:
	var s := _match()
	var c := _earth(s)
	c.buildings.erase("core:building/exchange")  # free a slot
	var cmd := _do(s, CmdQueueBuilding.TYPE, {"planet": c.id, "building": "core:building/farm"})
	assert_eq(cmd.error, "")
	assert_eq(c.queue[0].total_days, 90)
	_days(s, 89)
	assert_eq(c.buildings.count("core:building/farm"), 2, "not done after 89 days")
	_days(s, 1)
	assert_eq(c.buildings.count("core:building/farm"), 3, "done on day 90")
	assert_true(c.queue.is_empty())


func test_pace_scales_cost_and_days() -> void:
	var s := _match("pace_fast")
	var c := _earth(s)
	c.buildings.erase("core:building/exchange")
	_do(s, CmdQueueBuilding.TYPE, {"planet": c.id, "building": "core:building/farm"})
	assert_eq(c.queue[0].total_days, 54, "90 x 600 permille")
	assert_eq(c.queue[0].cost[ALLOYS], 48000, "80 x 600 permille")


func test_construction_stalls_without_materials_and_resumes() -> void:
	var s := _match()
	var c := _earth(s)
	c.buildings.erase("core:building/exchange")
	_do(s, CmdQueueBuilding.TYPE, {"planet": c.id, "building": "core:building/farm"})
	c.job_caps["core:job/worker"] = 0  # no alloy production while we watch
	c.job_caps["core:job/engineer"] = 0
	Economy.assign_jobs(c, _db)
	c.stockpile.take(ALLOYS, c.stockpile.milli(ALLOYS))
	_days(s, 10)
	assert_eq(c.queue[0].days_done, 0)
	assert_eq(c.queue[0].stalled_days, 10)
	c.stockpile.add(ALLOYS, 80000)
	_days(s, 90)
	assert_eq(c.buildings.count("core:building/farm"), 3, "finishes once materials arrive; nothing was lost")


func test_cancel_refunds_used_materials() -> void:
	var s := _match()
	var c := _earth(s)
	c.buildings.erase("core:building/exchange")
	_do(s, CmdQueueBuilding.TYPE, {"planet": c.id, "building": "core:building/farm"})
	_days(s, 45)
	var before := c.stockpile.milli(ALLOYS)
	assert_eq(_do(s, CmdCancelConstruction.TYPE, {"planet": c.id, "index": 0}).error, "")
	assert_eq(c.stockpile.milli(ALLOYS) - before, 40000, "half the build = 40 alloys back")


func test_building_rules() -> void:
	var s := _match()
	var c := _earth(s)
	assert_string_contains(_do(s, CmdQueueBuilding.TYPE, {"planet": c.id, "building": "core:building/farm"}).error, "no free building slot")
	c.buildings.erase("core:building/exchange")
	assert_string_contains(_do(s, CmdQueueBuilding.TYPE, {"planet": c.id, "building": "core:building/re_mine"}).error, "deposit")
	assert_string_contains(_do(s, CmdQueueBuilding.TYPE, {"planet": c.id, "building": "core:building/capital"}).error, "cannot be built")
	assert_string_contains(_do(s, CmdQueueBuilding.TYPE, {"planet": c.id, "building": "core:building/mine"}).error, "richness 1", "Earth's ore deposit holds one mine")


func test_station_site_needs_deliveries() -> void:
	var s := _match()
	var mercury := _body(s, "Mercury")
	assert_eq(_do(s, CmdQueueStation.TYPE, {"planet": mercury.id, "station": "core:station/mining_moon"}).error, "")
	var site: Station = BuildRules.stations_at(s, mercury.id)[0]
	assert_false(site.operational)
	_days(s, 5)
	assert_eq(site.build.days_done, 0, "an empty site waits for materials")
	site.stockpile.add(ALLOYS, 100000)  # what a freighter would deliver (WP5)
	_days(s, 60)
	assert_true(site.operational)
	_days(s, 30)
	assert_eq(site.stockpile.units(ORE), 10, "B11: 10 ore a month at a barren body")


func test_station_rules() -> void:
	var s := _match()
	var earth := s.galaxy.planet(_earth(s).id)
	assert_string_contains(_do(s, CmdQueueStation.TYPE, {"planet": earth.id, "station": "core:station/mining_belt"}).error, "can't orbit")
	assert_string_contains(_do(s, CmdQueueStation.TYPE, {"planet": earth.id, "station": "core:station/logistics_t2"}).error, "tier 1")
	assert_eq(_do(s, CmdQueueStation.TYPE, {"planet": earth.id, "station": "core:station/depot_t1"}).error, "", "Earth's third orbital slot is free")
	var luna := _body(s, "Luna")
	assert_eq(_do(s, CmdQueueStation.TYPE, {"planet": luna.id, "station": "core:station/depot_t1"}).error, "")
	assert_string_contains(_do(s, CmdQueueStation.TYPE, {"planet": luna.id, "station": "core:station/depot_t1"}).error, "orbital slot", "Luna has one slot")
	assert_string_contains(_do(s, CmdQueueStation.TYPE, {"planet": earth.id, "station": "core:station/outpost"}).error, "already claimed")


func test_outpost_claims_a_system() -> void:
	var s := _match()
	var target: StarSystem = null
	for sid: int in s.galaxy.systems:
		if s.galaxy.system(sid).owner == StateIO.NONE:
			target = s.galaxy.system(sid)
			break
	var body := target.planet_ids[0]
	assert_string_contains(_do(s, CmdQueueStation.TYPE, {"planet": body, "station": "core:station/outpost"}).error, "influence")
	_human(s).treasury["core:resource/influence"] = 100000  # claims cost influence (WP8, D9)
	assert_eq(_do(s, CmdQueueStation.TYPE, {"planet": body, "station": "core:station/outpost"}).error, "")
	BuildRules.stations_at(s, body)[0].stockpile.add(ALLOYS, 80000)
	_days(s, 60)
	assert_eq(target.owner, _human(s).id)


func test_upgrade() -> void:
	var s := _match()
	var hub: Station = BuildRules.stations_at(s, _earth(s).id)[0]
	assert_eq(_do(s, CmdUpgradeStation.TYPE, {"station": hub.id}).error, "")
	assert_eq([hub.build.total_days, hub.build.cost[ALLOYS], hub.build.cost["core:resource/components"]], [180, 300000, 40000])
	hub.stockpile.add(ALLOYS, 300000)
	hub.stockpile.add("core:resource/components", 40000)
	_days(s, 180)
	assert_eq(hub.def_id, "core:station/logistics_t2")
	assert_null(hub.build)


func test_set_focus_retools() -> void:
	var s := _match()
	var c := _earth(s)
	var mods := PlanetMods.of(c, _db)
	assert_eq(Economy.output_permille(c, "core:job/worker", _db, mods), 1500)
	assert_eq(_do(s, CmdSetFocus.TYPE, {"planet": c.id, "primary": "core:focus/industrial", "secondary": "core:focus/mining"}).error, "")
	assert_eq(c.retool_days, 180)
	assert_eq(Economy.output_permille(c, "core:job/worker", _db, PlanetMods.of(c, _db)), 1500 + 100 - 300, "Forge World +100, retooling -300")
	assert_string_contains(_do(s, CmdSetFocus.TYPE, {"planet": c.id, "primary": "core:focus/mining", "secondary": "core:focus/mining"}).error, "differ")


func test_deficit_halts_construction() -> void:
	var s := _match()
	var c := _earth(s)
	c.buildings.erase("core:building/exchange")
	_do(s, CmdQueueBuilding.TYPE, {"planet": c.id, "building": "core:building/farm"})
	_human(s).deficit_months = 1
	Builder.day_tick(s)
	assert_eq(c.queue[0].days_done, 0)


func test_move_construction_reorders_and_keeps_progress() -> void:
	var s := _match()
	var c := _earth(s)
	c.queue.clear()
	for b in ["core:building/farm", "core:building/mine"]:
		c.queue.append(BuildRules.new_construction(s, "building", b, {}, 90))
	c.queue[0].days_done = 5
	var first := c.queue[0].def_id
	var mv := CommandRegistry.create(CmdMoveConstruction.TYPE, _human(s).id, {"planet": c.id, "index": 1, "to": 0})
	assert_true(mv.validate(s))
	mv.apply(s)
	assert_eq(c.queue[1].def_id, first, "moved back, M4 WP15")
	assert_eq(c.queue[1].days_done, 5, "keeps its progress")
	var bad := CommandRegistry.create(CmdMoveConstruction.TYPE, _human(s).id, {"planet": c.id, "index": 2, "to": 0})
	assert_false(bad.validate(s), "out of range")
	var yard: Station = null
	for st: Station in s.stations.values():
		if st.owner == _human(s).id and st.def_id == "core:station/shipyard_t1":
			yard = st
	Shipyards.queue_ship(s, yard, "core:hull/freighter_light")
	Shipyards.queue_ship(s, yard, "core:hull/scout")
	var ship_mv := CommandRegistry.create(CmdMoveConstruction.TYPE, _human(s).id, {"station": yard.id, "ship_index": 1, "to": 0})
	assert_true(ship_mv.validate(s))
	ship_mv.apply(s)
	assert_eq(yard.ship_queue[0].def_id, "core:hull/scout")
