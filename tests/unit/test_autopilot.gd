extends GutTest
# M2 WP11: shared automation drives AI slots (Sub-spec D10); deterministic and never logged.

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func _settings() -> MatchSettings:
	var s := MatchSettings.new()
	s.add_player(0, "core:species/human", "human")
	s.add_player(1, "core:species/krothi", "ai")
	return s


func _match(seed_value := 7) -> MatchState:
	var errors: Array[String] = []
	return GalaxyGenerator.new_match(_settings(), seed_value, _db, errors)


func _run(s: MatchState, hours: int) -> void:
	var none: Array[Command] = []
	for i in hours:
		Sim.step(s, none)


func _count(s: MatchState, eid: int) -> Dictionary:
	return {
		"colonies": s.colonies.values().filter(func(c: Colony) -> bool: return c.owner == eid).size(),
		"stations": s.stations.values().filter(func(x: Station) -> bool: return x.owner == eid).size(),
	}


func test_ai_expands_and_humans_are_left_alone() -> void:
	var s := _match()
	var human: int = s.empires.keys()[0]
	var ai: int = s.empires.keys()[1]
	assert_true(Autopilot.is_ai(s, ai))
	assert_false(Autopilot.is_ai(s, human))
	var ai_before := _count(s, ai)
	var human_before := _count(s, human)
	_run(s, Calendar.HOURS_PER_YEAR)
	var ai_after := _count(s, ai)
	assert_gt(ai_after["colonies"], ai_before["colonies"], "the AI used its colony ship")
	assert_gt(ai_after["stations"], ai_before["stations"], "and built stations")
	assert_eq(_count(s, human)["colonies"], human_before["colonies"], "nobody expands for a human player")
	assert_true(s.command_log.is_empty(), "automation is never logged")


func test_replay_from_seed_matches_with_ai() -> void:
	var s := _match(11)
	var hours := 4 * Calendar.HOURS_PER_MONTH
	_run(s, hours)
	var replayed := Sim.replay(11, _settings(), _db, s.command_log, hours)
	assert_eq(replayed.checksum(), s.checksum())


func test_colony_target_rules() -> void:
	var s := _match()
	var ai: Empire = s.empires.values()[1]
	var home := s.galaxy.planet(ai.capital_planet).system_id
	var target := Autopilot.best_colony_target(s, ai.id, home)
	if target == StateIO.NONE:
		pass_test("no habitable target near this AI on this map")
		return
	var p := s.galaxy.planet(target)
	assert_null(s.colony(target))
	assert_false((_db.get_def(StringName(p.planet_type)) as PlanetTypeDef).orbital_only)
	var owner := s.galaxy.system(p.system_id).owner
	assert_true(owner == StateIO.NONE or owner == ai.id)
