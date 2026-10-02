extends GutTest
# M4 WP11: AI war operations (offensives, reserve, repairs, defending allies).

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func _match() -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "ai")
	settings.add_player(1, "core:species/krothi", "ai")
	settings.add_player(2, "core:species/human", "ai")
	var errors: Array[String] = []
	var s := GalaxyGenerator.new_match(settings, 3, _db, errors)
	var ids := _ids(s)
	for a in ids:
		for b in ids:
			if a != b:
				Relations._meet(s, a, b)
	return s


func _ids(s: MatchState) -> Array:
	var out := [0, 0, 0]
	for e: Empire in s.empires.values():
		out[e.player_slot] = e.id
	return out


func _home(s: MatchState, eid: int) -> int:
	return s.galaxy.planet(s.empire(eid).capital_planet).system_id


func _fleet(s: MatchState, eid: int, system: int, n: int) -> Fleet:
	var d: DesignDef = _db.get_def(&"core:design/human_cruiser_standard")
	var ids := []
	for i in n:
		var u := Shipyards.spawn(s, eid, String(d.hull), system)
		u.components.assign(Array(d.components).map(func(c: StringName) -> String: return String(c)))
		Fleets.arm(s, u)
		ids.append(u.id)
	return Fleets.create(s, eid, ids)


func test_offensive_against_undefended_colonies() -> void:
	var s := _match()
	var ids := _ids(s)
	s.empire(ids[0]).personality["caution"] = 0
	var f := _fleet(s, ids[0], _home(s, ids[0]), 4)
	Wars.declare(s, ids[0], ids[1], "")
	s.clear_scratch()
	MilitaryAutopilot.month_tick(s, ids[0], false)
	var l := Fleets.lead(s, f)
	assert_true(l.is_moving(), "the fleet sets out")
	assert_eq(s.galaxy.system(l.path[-1]).owner, ids[1], "toward an enemy system")


func test_home_reserve() -> void:
	var s := _match()
	var ids := _ids(s)
	s.empire(ids[0]).personality["caution"] = 100
	var f := _fleet(s, ids[0], _home(s, ids[0]), 4)
	Wars.declare(s, ids[0], ids[1], "")
	s.clear_scratch()
	MilitaryAutopilot.month_tick(s, ids[0], false)
	assert_false(Fleets.lead(s, f).is_moving(), "its only fleet is the home reserve (Caution 100: 50%)")


func test_damaged_fleets_repair() -> void:
	var s := _match()
	var ids := _ids(s)
	var away := s.galaxy.lane(s.galaxy.system(_home(s, ids[0])).lane_ids[0]).other_end(_home(s, ids[0]))
	var f := _fleet(s, ids[0], away, 2)
	for sid in f.ships():
		(s.units.get_or(sid) as Unit).hp = 100
	s.clear_scratch()
	MilitaryAutopilot.month_tick(s, ids[0], false)
	var l := Fleets.lead(s, f)
	assert_true(l.is_moving())
	assert_eq(l.path[-1], _home(s, ids[0]), "home to the shipyard")


func test_defends_an_ally() -> void:
	var s := _match()
	var ids := _ids(s)
	Treaties.sign(s, ids[2], ids[0], "core:treaty/defence_pact")
	Wars.declare(s, ids[1], ids[2], "claim")
	s.wars[Battles.war_key(ids[0], ids[1])] = true
	var ally_home := _home(s, ids[2])
	var raider := Shipyards.spawn(s, ids[1], "core:hull/krothi_corvette_mk1", ally_home)
	raider.components.assign(Array((_db.get_def(&"core:design/krothi_corvette_standard") as DesignDef).components).map(func(c: StringName) -> String: return String(c)))
	Fleets.arm(s, raider)
	var f := _fleet(s, ids[0], _home(s, ids[0]), 4)
	s.empire(ids[0]).personality["caution"] = 0
	s.clear_scratch()
	assert_true(MilitaryAutopilot.threats(s, ids[0]).has(ally_home), "the ally's system counts as ours")
	MilitaryAutopilot.month_tick(s, ids[0], false)
	assert_eq(Fleets.lead(s, f).path[-1] if Fleets.lead(s, f).is_moving() else -1, ally_home, "off to defend it")
