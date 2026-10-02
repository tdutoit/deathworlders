extends GutTest
# M4 WP10: AI personalities and the strategic loop (Sub-spec E11-E12, E16).

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


## Three AI empires (human, human, Krothi) in contact, with influence.
func _match() -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "ai")
	settings.add_player(1, "core:species/human", "ai")
	settings.add_player(2, "core:species/krothi", "ai")
	var errors: Array[String] = []
	var s := GalaxyGenerator.new_match(settings, 3, _db, errors)
	var ids := _ids(s)
	for a in ids:
		for b in ids:
			if a != b:
				Relations._meet(s, a, b)
		s.empire(a).treasury["core:resource/influence"] = 500 * 1000
	return s


func _ids(s: MatchState) -> Array:
	var out := [0, 0, 0]
	for e: Empire in s.empires.values():
		out[e.player_slot] = e.id
	return out


func _fleet(s: MatchState, eid: int, design: String, system: int, n: int) -> void:
	var d: DesignDef = _db.get_def(StringName(design))
	for i in n:
		var u := Shipyards.spawn(s, eid, String(d.hull), system)
		u.components.assign(Array(d.components).map(func(c: StringName) -> String: return String(c)))
		Fleets.arm(s, u)


func test_personalities_rolled() -> void:
	var s := _match()
	for e: Empire in s.empires.values():
		var sd: SpeciesDef = _db.get_def(StringName(e.species))
		assert_eq(e.personality.size(), 7)
		for w: String in SpeciesDef.PERSONALITY:
			assert_between(int(e.personality[w]), maxi(0, int(sd.ai_personality[w]) - 15), mini(100, int(sd.ai_personality[w]) + 15))


func test_ais_sign_treaties() -> void:
	var s := _match()
	for m in 6:
		s.clear_scratch()
		StrategicAI.month_tick(s)
	assert_gt(s.treaties.size(), 0, "AIs that like each other sign treaties")


func test_no_wars_in_the_first_years() -> void:
	var s := _match()
	var ids := _ids(s)
	_fleet(s, ids[2], "core:design/krothi_cruiser_standard", s.galaxy.planet(s.empire(ids[2]).capital_planet).system_id, 10)
	s.empire(ids[2]).personality["aggression"] = 100
	s.empire(ids[2]).personality["caution"] = 0
	for m in 3:
		s.clear_scratch()
		StrategicAI.month_tick(s)
	assert_true(s.wars.is_empty(), "E16: no AI war before year 10")


func test_strong_aggressive_ai_declares_with_a_cause() -> void:
	var s := _match()
	var ids := _ids(s)
	s.tick = 10 * Calendar.HOURS_PER_YEAR
	var k := s.empire(ids[2])
	k.personality["aggression"] = 100
	k.personality["caution"] = 0
	var target: int = ids[0]
	var sid := s.galaxy.planet(s.empire(target).capital_planet).system_id
	for lid in s.galaxy.system(sid).lane_ids:
		s.galaxy.system(s.galaxy.lane(lid).other_end(sid)).owner = ids[2]  # the Krothi next door
	s.claims[Wars.claim_key(ids[2], sid)] = 0
	_fleet(s, ids[2], "core:design/krothi_cruiser_standard", s.galaxy.planet(k.capital_planet).system_id, 10)
	Relations.add_event(s, ids[2], target, "humiliated", -40)
	s.clear_scratch()
	k.ai_actions = 5
	StrategicAI.month_tick(s)
	assert_true(s.wars.has(Battles.war_key(ids[2], target)), "a much stronger, aggressive neighbour with a claim attacks")
	assert_eq(Wars.war_of(s, ids[2], target).casus_belli, "claim")


func test_losing_ai_sues_for_peace() -> void:
	var s := _match()
	var ids := _ids(s)
	var w := Wars.declare(s, ids[0], ids[1], "")
	w.add_score(ids[0], 40000)
	s.empire(ids[1]).war_exhaustion = 80000
	s.clear_scratch()
	StrategicAI.month_tick(s)
	assert_false(s.wars.has(Battles.war_key(ids[0], ids[1])), "peace made (one side demanded, the other accepted)")
