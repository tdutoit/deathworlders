extends GutTest
# M2 WP7b: two-tier logistics (Sub-spec D5): governor demands, hub collection, exports, import requests.

const ORE := "core:resource/ore"
const FOOD := "core:resource/food"
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


func _earth(s: MatchState) -> Colony:
	return s.colony(_human(s).capital_planet)


func _days(s: MatchState, n: int) -> void:
	var none: Array[Command] = []
	for i in n * Calendar.HOURS_PER_DAY:
		Sim.step(s, none)


func _do(s: MatchState, type_id: StringName, payload: Dictionary) -> Command:
	var cmd := CommandRegistry.create(type_id, _human(s).id, payload)
	Sim.execute(s, [cmd] as Array[Command])
	return cmd


func _core_hub(s: MatchState) -> int:
	return SectorLogistics.core_sector(s, _human(s).id).hub


func _fill_belts(s: MatchState) -> void:
	for pid: int in s.galaxy.planets:
		if s.galaxy.planet(pid).name == "Asteroid Belt":
			for st in BuildRules.stations_at(s, pid):
				st.stockpile.add(ORE, 150000, 200000)


func _jobs_to(s: MatchState, holder: int, res: String) -> Array:
	return s.units.values().filter(func(u: Unit) -> bool:
		return not u.job.is_empty() and u.job["dest"] == holder and u.job["resource"] == res)


## A second sector anchored on a Logistics-focus colony 3 lanes from home (inside the T1 hub's range).
func _outer_sector(s: MatchState) -> Colony:
	var dist := AutoLogistics._hops_from(s, s.galaxy.planet(_earth(s).id).system_id, {})
	for sid: int in IdMap.sort_keys(dist.keys()):
		if dist[sid] == 3:
			var sys := s.galaxy.system(sid)
			sys.owner = _human(s).id
			var c := Colony.new()
			c.id = sys.planet_ids[0]
			c.owner = _human(s).id
			c.pops = {_human(s).species: 4}
			c.primary_focus = "core:focus/logistics"
			s.colonies.put(c.id, c)
			assert_eq(_do(s, CmdCreateSector.TYPE, {"hub": c.id}).error, "")
			return c
	return null


func test_earth_gets_belt_ore_without_orders() -> void:
	var s := _match()
	var earth := _earth(s)
	earth.stockpile.take(ORE, earth.stockpile.milli(ORE) - 10000)  # 10 left; workers need 36 a month
	_fill_belts(s)
	_days(s, 1)
	var jobs := _jobs_to(s, earth.id, ORE)
	assert_eq(jobs.size(), 1, "the governor asks for 2 months of worker ore")
	assert_eq(s.station(jobs[0].job["source"]).def_id, "core:station/mining_belt", "from the belt, inside the sector")


func test_hub_collects_mining_output() -> void:
	var s := _match()
	var hub := s.station(_core_hub(s))
	_fill_belts(s)
	_days(s, 30)
	assert_gt(hub.stockpile.units(ORE), 0, "belt ore is gathered at the hub (Low priority)")


func test_local_demands_stay_in_the_sector_until_an_import_is_approved() -> void:
	var s := _match()
	var outer := _outer_sector(s)
	_days(s, 1)
	assert_eq(_jobs_to(s, outer.id, FOOD).size(), 0, "no food inside its own sector")
	var reqs := SectorLogistics.import_requests(s, _human(s).id)
	assert_true(reqs.any(func(r: Dictionary) -> bool: return r["holder"] == outer.id and r["resource"] == FOOD), str(reqs))
	assert_eq(_do(s, CmdApproveImport.TYPE, {"holder": outer.id, "resource": FOOD, "amount": 20}).error, "")
	_days(s, 1)
	var jobs := _jobs_to(s, outer.id, FOOD)
	assert_eq(jobs.size(), 1, "the approved import is a trunk shipment from outside the sector")
	assert_eq(jobs[0].job["source"], _earth(s).id)


func test_exports_go_to_the_core_hub() -> void:  # the Core hub is the capital's logistics station
	var s := _match()
	var outer := _outer_sector(s)
	outer.stockpile.add(ALLOYS, 400000)  # Logistics focus: cap 750, reserve 150; surplus 250, quota 50% = 125
	var export := SectorLogistics.demands(s, _human(s).id).filter(func(d: Dictionary) -> bool:
		return d["holder"] == _core_hub(s) and d["resource"] == ALLOYS)
	assert_eq(export.size(), 1)
	assert_eq(export[0]["target"] - s.station(_core_hub(s)).stockpile.milli(ALLOYS), 125000)
	assert_eq(export[0]["sources"], [outer.id])
	var sec: Sector = s.sectors.values()[-1]
	assert_eq(_do(s, CmdSetExportQuota.TYPE, {"sector": sec.id, "resource": ALLOYS, "permille": 0}).error, "")
	export = SectorLogistics.demands(s, _human(s).id).filter(func(d: Dictionary) -> bool:
		return d["holder"] == _core_hub(s) and d["resource"] == ALLOYS)
	assert_eq(export.size(), 0, "quota 0: nothing goes up the trunk")


func test_manual_planets_make_no_governor_demands() -> void:
	var s := _match()
	var earth := _earth(s)
	_do(s, CmdSetAutonomy.TYPE, {"planet": earth.id, "autonomy": "manual"})
	var mine := SectorLogistics.demands(s, _human(s).id).filter(func(d: Dictionary) -> bool: return d["holder"] == earth.id)
	assert_eq(mine.size(), 0)
