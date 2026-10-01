extends GutTest
# M2 WP2: colonies, pops, jobs and the planet economy against Sub-spec B19 (as amended 2026-10-01).

const FOOD := "core:resource/food"
const ORE := "core:resource/ore"
const ALLOYS := "core:resource/alloys"
const CREDITS := "core:resource/credits"

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func _match(seed_value := 3) -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	var errors: Array[String] = []
	return GalaxyGenerator.new_match(settings, seed_value, _db, errors)


func _earth(s: MatchState) -> Colony:
	return s.colony((s.empires.values()[0] as Empire).capital_planet)


func _run_days(s: MatchState, days: int) -> void:
	var none: Array[Command] = []
	for i in days * Calendar.HOURS_PER_DAY:
		Sim.step(s, none)


func _units(flows: Dictionary, res: String) -> float:
	return flows.get(res, 0) / 1000.0


func test_opening_matches_b19() -> void:
	var s := _match()
	var c := _earth(s)
	assert_not_null(c)
	assert_eq(c.total_pops(), 24)
	assert_eq(c.jobs, {"core:job/farmer": 6, "core:job/miner": 2, "core:job/worker": 6, "core:job/engineer": 2,
		"core:job/munitions_worker": 1, "core:job/researcher": 4, "core:job/clerk": 3})
	var earth := s.galaxy.planet(c.id)
	assert_eq(Economy.housing(s, c, earth, _db), 36, "Large 28 + capital 8, humans 1000 on Terran")
	assert_eq(Economy.slots(c, earth, _db), 10, "Large 8 + capital 2")
	assert_eq(Economy.used_slots(c, _db), 10, "ten B19 buildings fit")
	assert_eq(c.stockpile.units("core:resource/rare_earths"), 100)
	assert_eq((s.empires.values()[0] as Empire).treasury[CREDITS], 500000)


func test_first_month_flows_match_b19() -> void:
	var s := _match()
	_run_days(s, 30)
	var c := _earth(s)
	var p := c.last_produced
	var u := c.last_consumed
	assert_eq(_units(p, FOOD), 36.0)
	assert_eq(_units(u, FOOD), 24.0)
	assert_eq(_units(p, ORE), 8.0, "2 miners (belt stations arrive in WP3)")
	assert_eq(_units(u, ORE), 38.0, "36 workers + 2 munitions")
	assert_eq(_units(p, ALLOYS), 27.0)
	assert_eq(_units(u, ALLOYS), 2.0)
	assert_eq(_units(p, "core:resource/components"), 6.0)
	assert_eq(_units(p, "core:resource/munitions"), 12.0)
	assert_eq(_units(u, "core:resource/rare_earths"), 2.0)
	assert_eq(_units(p, "core:resource/research"), 55.0, "40 capital + 15 researchers")
	assert_eq(_units(p, CREDITS), 44.0, "20 capital + 12 clerks + 12 taxes")
	var e: Empire = s.empires.values()[0]
	assert_eq(e.treasury[CREDITS], (500 + 44 - 10 - 7) * 1000, "minus 10 building and 7 station upkeep")
	assert_eq(c.stability, 55, "base 50 + food surplus 5")


func test_months_add_up_exactly() -> void:
	# Spreading monthly totals over days must not drift: 3 months of 6 Food per farmer = 3 x 36.
	var s := _match()
	var c := _earth(s)
	var food_before := c.stockpile.milli(FOOD)
	_run_days(s, 90)
	assert_eq(c.stockpile.milli(FOOD) - food_before, 3 * (36 - 24) * 1000)


func test_input_shortage_scales_output() -> void:
	var s := _match()
	var c := _earth(s)
	c.jobs = {"core:job/worker": 6}  # only workers: they need 36 ore a month, 1.2 on day 0
	c.stockpile.take(ORE, c.stockpile.milli(ORE))
	c.stockpile.add(ORE, 600)  # half a day's need
	var alloys := c.stockpile.milli(ALLOYS)
	Economy.day_tick(s, 0)
	assert_eq(c.stockpile.milli(ORE), 0)
	assert_eq(c.stockpile.milli(ALLOYS) - alloys, 450, "half of day 0's 0.9 alloys")


func test_overflow_is_lost() -> void:
	var s := _match()
	var c := _earth(s)
	assert_eq(c.stockpile.add(ALLOYS, 1000000, 500000), 900000, "400 + 1000 into a 500 cap: 900 lost")
	assert_eq(c.stockpile.units(ALLOYS), 500)
	Economy.day_tick(s, 0)
	# Workers (priority 30) produce before Engineers (31) eat 0.066 alloys, so the day ends just under the cap:
	# the 0.9 alloys produced into a full stockpile were lost, not stored above it.
	assert_lte(c.stockpile.milli(ALLOYS), 500000)
	assert_gt(c.stockpile.milli(ALLOYS), 499900)


func test_starvation() -> void:
	var s := _match()
	var c := _earth(s)
	c.job_caps["core:job/farmer"] = 0
	c.stockpile.take(FOOD, c.stockpile.milli(FOOD))
	Economy.assign_jobs(c, _db)
	_run_days(s, 30)
	assert_eq(c.starving_months, 1)
	assert_eq(c.total_pops(), 24)
	assert_lt(c.stability, 55)
	c.job_caps["core:job/farmer"] = 0  # the starving rule would hire farmers first; keep them off
	_run_days(s, 60)
	assert_eq(c.starving_months, 3)
	assert_eq(c.total_pops(), 23, "-1 pop every 3 months of starvation")


func test_growth_adds_a_pop() -> void:
	var s := _match()
	var c := _earth(s)
	c.growth = 990  # + (30 + 3 x 12 free housing) this month
	_run_days(s, 30)
	assert_eq(c.total_pops(), 25)
	assert_eq(c.growth, 990 + 66 - 1000)


func test_credit_deficit() -> void:
	var s := _match()
	var e: Empire = s.empires.values()[0]
	var drain := Colony.new()  # a pop-less colony with 600 credits of upkeep a month
	drain.id = (s.galaxy.planets.keys()[-1])
	drain.owner = e.id
	for i in 600:
		drain.buildings.append("core:building/farm")
	s.colonies.put(drain.id, drain)
	_run_days(s, 30)
	assert_eq(e.treasury[CREDITS], 0)
	assert_eq(e.deficit_months, 1)
	_run_days(s, 30)
	assert_eq(_earth(s).stability, 55 - 10 * 1, "-10 per month in deficit (counted at the start of the month)")


func test_economy_is_in_the_checksum() -> void:
	var s := _match()
	var before := s.checksum()
	_earth(s).stockpile.add(FOOD, 1)
	assert_ne(s.checksum()["economy"], before["economy"])
	assert_eq(MatchState.from_dict(s.to_dict()).checksum(), s.checksum(), "colonies round-trip")
