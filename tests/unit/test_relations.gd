extends GutTest
# M4 WP3: relations: contact, opinion (affinity, standing, events), trust, Reputation (Sub-spec E1-E3, E14).

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func _match() -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "human")
	settings.add_player(1, "core:species/vesskar", "ai")
	var errors: Array[String] = []
	return GalaxyGenerator.new_match(settings, 3, _db, errors)


func _ids(s: MatchState) -> Array:
	var h := -1
	var v := -1
	for e: Empire in s.empires.values():
		if e.species == "core:species/human":
			h = e.id
		else:
			v = e.id
	return [h, v]


func _home(s: MatchState, eid: int) -> int:
	return s.galaxy.planet(s.empire(eid).capital_planet).system_id


func test_no_contact_at_start_then_by_ship() -> void:
	var s := _match()
	var ids := _ids(s)
	Relations.month_tick(s)
	assert_false(Relations.has_contact(s, ids[0], ids[1]), "homes are far apart on this map")
	var scout := Shipyards.spawn(s, ids[0], "core:hull/scout", _home(s, ids[1]))
	assert_not_null(scout)
	Relations.month_tick(s)
	assert_true(Relations.has_contact(s, ids[0], ids[1]), "a ship in their space")
	assert_true(Relations.has_contact(s, ids[1], ids[0]), "contact is mutual")


func test_contact_by_proximity() -> void:
	var s := _match()
	var ids := _ids(s)
	var vhome := _home(s, ids[1])
	var near := AutoLogistics.hops_within(s, vhome, 3, {})
	for sid: int in IdMap.sort_keys(near.keys()):
		if int(near[sid]) == 3 and s.galaxy.system(sid).owner == StateIO.NONE:
			s.galaxy.system(sid).owner = ids[0]
			break
	Relations.month_tick(s)
	assert_true(Relations.has_contact(s, ids[0], ids[1]), "own system within 3 lanes")


func _contact(s: MatchState) -> Array:
	var ids := _ids(s)
	Relations._meet(s, ids[0], ids[1])
	Relations._meet(s, ids[1], ids[0])
	return ids


func test_affinity_and_trust_start() -> void:
	var s := _match()
	var ids := _contact(s)
	assert_eq(Relations.opinion(s, ids[1], ids[0]), -20, "Vess'kar view humans as primitives (E2)")
	assert_eq(Relations.opinion(s, ids[0], ids[1]), 0)
	assert_eq(Relations.trust(s, ids[1], ids[0]), 10, "affinity <= -20: wary start (E3)")
	assert_eq(Relations.trust(s, ids[0], ids[1]), 20)
	Relations.change_trust(s, ids[0], ids[1], 200)
	assert_eq(Relations.trust(s, ids[0], ids[1]), 100, "clamped")


func test_border_common_enemy_and_war_cap() -> void:
	var s := _match()
	var ids := _contact(s)
	var vhome := _home(s, ids[1])
	var lid: int = s.galaxy.system(vhome).lane_ids[0]
	s.galaxy.system(s.galaxy.lane(lid).other_end(vhome)).owner = ids[0]
	Relations.month_tick(s)
	assert_eq(Relations.opinion(s, ids[0], ids[1]), -10, "shared border")
	s.wars[Battles.war_key(ids[0], ids[1])] = true
	Relations.month_tick(s)
	assert_eq(Relations.opinion(s, ids[1], ids[0]), -50, "at war: at most -50")
	assert_lt(Relations.opinion(s, ids[1], ids[0]), 0)


func test_events_cap_and_decay() -> void:
	var s := _match()
	var ids := _contact(s)
	for i in 10:
		Relations.add_event(s, ids[0], ids[1], "gift", 5)
	assert_eq(Relations.opinion(s, ids[0], ids[1]), 25, "gifts cap at +25")
	Relations.add_event(s, ids[0], ids[1], "humiliated", -40)
	assert_eq(Relations.opinion(s, ids[0], ids[1]), -15)
	for m in 4:
		Relations.month_tick(s)
	var rel := Relations.of(s, ids[0], ids[1])
	assert_eq(int(rel.events["gift"][0]), 21, "-1 a month")
	assert_eq(int(rel.events["humiliated"][0]), -38, "-1 every 2 months")
	var parts := Relations.breakdown(s, ids[0], ids[1]).map(func(p: Array) -> String: return p[0])
	assert_has(parts, "OPINION_GIFT")
	var back := MatchState.from_dict(s.to_dict())
	back.defs = _db
	assert_eq(Relations.opinion(back, ids[0], ids[1]), Relations.opinion(s, ids[0], ids[1]), "saved")
	assert_eq(back.checksum()["diplomacy"], s.checksum()["diplomacy"])


func test_reputation_clamped() -> void:
	var s := _match()
	var ids := _ids(s)
	Relations.change_reputation(s, ids[0], -900)
	assert_eq(s.empire(ids[0]).reputation, -500)
