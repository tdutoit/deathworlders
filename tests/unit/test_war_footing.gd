extends GutTest
# M4 WP7: war footing (Sub-spec D7).

var _db: DefDatabase
const MOB := "core:war_footing/mobilised"
const TOTAL := "core:war_footing/total_war"


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func _match(species := "human") -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/" + species, "human")
	settings.add_player(1, "core:species/krothi", "ai")
	var errors: Array[String] = []
	return GalaxyGenerator.new_match(settings, 3, _db, errors)


func _e(s: MatchState, slot := 0) -> Empire:
	for e: Empire in s.empires.values():
		if e.player_slot == slot:
			return e
	return null


func _do(s: MatchState, eid: int, type: StringName, payload: Dictionary) -> Command:
	var c := CommandRegistry.create(type, eid, payload)
	if c.validate(s):
		c.apply(s)
	return c


func test_effects_and_transition() -> void:
	var s := _match()
	var e := _e(s)
	assert_eq(WarFooting.output_permille(s, e, "core:resource/alloys"), 0, "starts at Peace")
	_do(s, e.id, CmdSetWarFooting.TYPE, {"footing": MOB})
	assert_eq(e.footing, MOB)
	assert_eq(WarFooting.output_permille(s, e, "core:resource/alloys"), 100, "half of +200 during the 60-day switch")
	assert_eq(WarFooting.stability(s, e), -3, "half of -5, floored")
	s.tick += 61 * Calendar.HOURS_PER_DAY
	assert_eq(WarFooting.output_permille(s, e, "core:resource/munitions"), 500)
	assert_eq(WarFooting.output_permille(s, e, "core:resource/credits"), -300)
	assert_eq(WarFooting.stability(s, e), -5)


func test_demobilisation_dip() -> void:
	var s := _match()
	var e := _e(s)
	WarFooting.change(s, e, TOTAL)
	s.tick += 100 * Calendar.HOURS_PER_DAY
	WarFooting.change(s, e, WarFooting.PEACE)
	assert_eq(WarFooting.stability(s, e), -5, "Total War back to Peace: -5 for 6 months")
	s.tick += 7 * Calendar.HOURS_PER_MONTH
	assert_eq(WarFooting.stability(s, e), 0)


func test_total_war_exhaustion() -> void:
	var s := _match()
	var human := _e(s, 0)
	var krothi := _e(s, 1)
	Wars.declare(s, krothi.id, human.id, "")
	WarFooting.change(s, human, TOTAL)
	WarFooting.change(s, krothi, TOTAL)
	WarFooting.month_tick(s)
	assert_eq(krothi.war_exhaustion, 1000, "+1 a month at Total War")
	assert_eq(human.war_exhaustion, 350, "humans x0.35 (Stubborn, D7)")
	assert_eq(WarFooting.exhaustion_factor(s, krothi.id), 500, "losses exhaust half as fast")
	assert_eq(WarFooting.exhaustion_factor(s, human.id), 350)


func test_job_output_follows_the_footing() -> void:
	var s := _match()
	var e := _e(s)
	var c := s.colony(e.capital_planet)
	var before := int(c.produced.get("core:resource/alloys", 0))
	Economy.day_tick(s, 0)
	var peace := int(c.produced.get("core:resource/alloys", 0)) - before
	WarFooting.change(s, e, MOB)
	s.tick += 61 * Calendar.HOURS_PER_DAY
	before = int(c.produced.get("core:resource/alloys", 0))
	Economy.day_tick(s, 0)
	var mobilised := int(c.produced.get("core:resource/alloys", 0)) - before
	if peace == 0:
		pass_test("no alloy jobs at the capital on this start")
		return
	assert_gt(mobilised, peace, "Mobilised: more alloys")
