extends GutTest
# M3 WP10: defensive autopilot for AI slots.

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func _match() -> MatchState:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "ai")
	var errors: Array[String] = []
	return GalaxyGenerator.new_match(settings, 3, _db, errors)


func _ai(s: MatchState) -> Empire:
	return s.empires.values()[0]


func _home_sys(s: MatchState) -> int:
	return s.galaxy.planet(_ai(s).capital_planet).system_id


func _own_at(s: MatchState, hops: int) -> int:
	var dist := AutoLogistics._hops_from(s, _home_sys(s), {})
	for sid: int in IdMap.sort_keys(dist.keys()):
		if dist[sid] == hops:
			s.galaxy.system(sid).owner = _ai(s).id
			return sid
	return -1


func _fleet(s: MatchState, system: int, n := 1) -> Fleet:
	var d: DesignDef = _db.get_def(&"core:design/human_cruiser_standard")
	var ids := []
	for i in n:
		var u := Shipyards.spawn(s, _ai(s).id, String(d.hull), system)
		u.components.assign(Array(d.components).map(func(c: StringName) -> String: return String(c)))
		Fleets.arm(s, u)
		ids.append(u.id)
	return Fleets.create(s, _ai(s).id, ids, "test")


func _warship_queue(s: MatchState) -> int:
	var n := 0
	for st: Station in s.stations.values():
		n += st.ship_queue.filter(func(q: Construction) -> bool: return q.design != 0).size()
	return n


func _second_yard(s: MatchState) -> void:
	var y: Station
	for st: Station in s.stations.values():
		if (_db.get_def(StringName(st.def_id)) as StationDef).function == &"shipyard":
			y = st
	var copy := Station.from_dict(y.to_dict())
	copy.id = s.alloc_id()
	copy.ship_queue.clear()
	s.stations.put(copy.id, copy)


func test_builds_a_defence_fleet() -> void:
	var s := _match()
	MilitaryAutopilot.month_tick(s, _ai(s).id, true)
	assert_eq(_warship_queue(s), 0, "shipyards first")
	_second_yard(s)
	MilitaryAutopilot.month_tick(s, _ai(s).id, true)
	assert_eq(_warship_queue(s), 1, "under ai_min_fleet_value: one warship queued")
	MilitaryAutopilot.month_tick(s, _ai(s).id, true)
	assert_eq(_warship_queue(s), 1, "one at a time")


func test_no_building_when_the_economy_cannot_expand() -> void:
	var s := _match()
	_second_yard(s)
	MilitaryAutopilot.month_tick(s, _ai(s).id, false)
	assert_eq(_warship_queue(s), 0)


func test_idle_fleets_in_one_system_merge() -> void:
	var s := _match()
	_fleet(s, _home_sys(s))
	_fleet(s, _home_sys(s))
	MilitaryAutopilot.month_tick(s, _ai(s).id, false)
	assert_eq(s.fleets.values().filter(func(f: Fleet) -> bool: return f.owner == _ai(s).id).size(), 1)


func test_fleet_sent_at_a_raider_in_territory() -> void:
	var s := _match()
	var sys := _own_at(s, 2)
	var f := _fleet(s, _home_sys(s), 2)
	Pirates.spawn_raider(s, sys, _ai(s).id)
	assert_true(MilitaryAutopilot.threats(s, _ai(s).id).has(sys))
	MilitaryAutopilot.month_tick(s, _ai(s).id, false)
	var l := Fleets.lead(s, f)
	assert_true(l.is_moving(), "under way")
	assert_eq(l.path[-1], sys, "toward the raider")


func test_too_weak_fleet_stays_home() -> void:
	var s := _match()
	var sys := _own_at(s, 2)
	var f := _fleet(s, _home_sys(s), 1)
	for i in 12:
		Pirates.spawn_raider(s, sys, _ai(s).id)
	MilitaryAutopilot.month_tick(s, _ai(s).id, false)
	assert_false(Fleets.lead(s, f).is_moving(), "below ai_attack_ratio")


func test_convoy_losses_start_patrol_and_escort() -> void:
	var s := _match()
	var a := _own_at(s, 1)
	var hub := -1
	for u: Unit in s.units.values():
		if u.kind == "freighter" and u.home != StateIO.NONE:
			hub = u.home
	_fleet(s, _home_sys(s))
	var g := _fleet(s, a)
	for i in 2:
		_ai(s).losses.append({"tick": s.tick, "unit": 1000 + i, "system": a, "hull": "", "cargo": {}, "hub": hub})
	MilitaryAutopilot.month_tick(s, _ai(s).id, false)
	var missions := s.fleets.values().map(func(f: Fleet) -> String: return f.mission)
	assert_true("patrol" in missions, "a patrol over the loss systems")
	assert_true("escort" in missions, "an escort for the hub that lost freighters")
	var patrol: Fleet = s.fleets.values().filter(func(f: Fleet) -> bool: return f.mission == "patrol")[0]
	assert_eq(patrol.patrol, [a] as Array[int])
	s.tick += Calendar.HOURS_PER_MONTH * 4
	MilitaryAutopilot.month_tick(s, _ai(s).id, false)
	assert_eq(s.fleets.values().filter(func(f: Fleet) -> bool: return f.mission != "").size(), 0, "losses stopped: back to idle")
	assert_not_null(g)


func test_beyond_the_minimum_only_while_threatened() -> void:
	var s := _match()
	_second_yard(s)
	_fleet(s, _home_sys(s), 2)  # ai_min_fleet_value already met
	_ai(s).credit_net = 200000  # room in the upkeep budget
	var r: CombatRulesDef = _db.get_def(CombatRulesDef.ID)
	assert_false(MilitaryAutopilot.threatened(s, _ai(s).id, r))
	MilitaryAutopilot.month_tick(s, _ai(s).id, true)
	assert_eq(_warship_queue(s), 0, "quiet frontier: the economy comes first")
	Pirates.spawn_raider(s, _own_at(s, 3), _ai(s).id)
	assert_true(MilitaryAutopilot.threatened(s, _ai(s).id, r))
	MilitaryAutopilot.month_tick(s, _ai(s).id, true)
	assert_eq(_warship_queue(s), 1, "raiders hunting: grow the fleet within budget")


func test_stalled_civilian_build_holds_warships_at_peace() -> void:
	var s := _match()
	_second_yard(s)
	_fleet(s, _home_sys(s), 1)  # past half the minimum fleet, under the minimum
	var col: Colony = s.colonies.get_or(_ai(s).capital_planet)
	var farm := Construction.new()
	farm.kind = "building"
	farm.def_id = "core:building/farm"
	farm.cost = {"core:resource/alloys": 50000}
	farm.stalled_days = 31
	col.queue.append(farm)
	MilitaryAutopilot.month_tick(s, _ai(s).id, true)
	assert_eq(_warship_queue(s), 0, "a farm waiting for alloys comes first (WP14)")
	farm.stalled_days = 0
	MilitaryAutopilot.month_tick(s, _ai(s).id, true)
	assert_eq(_warship_queue(s), 1, "then the fleet")


func test_idle_scout_seeks_an_unmet_empire() -> void:
	var settings := MatchSettings.new()
	settings.add_player(0, "core:species/human", "ai")
	settings.add_player(1, "core:species/krothi", "ai")
	var errors: Array[String] = []
	var s := GalaxyGenerator.new_match(settings, 3, _db, errors)
	var me: Empire = s.empires.values()[0]
	var scouts := s.units.values().filter(func(u: Unit) -> bool: return u.owner == me.id and u.kind == "scout")
	assert_eq(scouts.size(), 1, "every empire starts with a scout")
	MilitaryAutopilot.month_tick(s, me.id, false)
	assert_true((scouts[0] as Unit).is_moving(), "off to find the neighbours (first contact, WP14)")
