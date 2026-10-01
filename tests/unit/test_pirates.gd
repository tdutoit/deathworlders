extends GutTest
# M2 WP10: frontier security and pirates (Sub-spec B9, D9; M2 frontier-only rules).

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


func _home_sys(s: MatchState) -> int:
	return s.galaxy.planet(_human(s).capital_planet).system_id


## Claims (and returns) a system `hops` lanes from home.
func _own_at(s: MatchState, hops: int) -> int:
	var dist := AutoLogistics._hops_from(s, _home_sys(s), {})
	for sid: int in IdMap.sort_keys(dist.keys()):
		if dist[sid] == hops:
			s.galaxy.system(sid).owner = _human(s).id
			return sid
	return -1


func _raiders(s: MatchState) -> Array:
	return s.units.values().filter(func(u: Unit) -> bool: return u.kind == "raider")


func test_security() -> void:
	var s := _match()
	assert_eq(Pirates.security(s, _home_sys(s)), 20, "D9 base")
	var earth := s.colony(_human(s).capital_planet)
	earth.buildings.append("core:building/barracks")
	earth.jobs["core:job/soldier"] = 3
	assert_eq(Pirates.security(s, _home_sys(s)), 35, "+5 per garrison company")
	var far := _own_at(s, 7)
	if far != -1:
		assert_eq(Pirates.security(s, far), 10, "reach 7+: halved")


func test_core_never_spawns_pirates() -> void:
	var s := _match()
	for i in 120:
		Pirates.month_tick(s)
	assert_eq(_raiders(s).size(), 0, "Sol is reach 0; only frontier systems roll")


func test_frontier_spawns_up_to_the_cap() -> void:
	var s := _match()
	for h in [3, 4]:
		_own_at(s, h)
	for i in 120:
		Pirates.month_tick(s)
		assert_lte(Pirates.raiders_hunting(s, _human(s).id), 3)
	assert_gt(s.units.values().filter(func(u: Unit) -> bool: return u.kind == "raider").size() + s.pirate_bases.size(), 0,
		"10 years of 10% monthly rolls produced pirates")


func test_passage_rolls_lose_freighters() -> void:
	var s := _match()
	var sys := _own_at(s, 3)
	Pirates.spawn_raider(s, sys, _human(s).id)
	var victims := []
	for i in 20:
		var f := Shipyards.spawn(s, _human(s).id, "core:hull/freighter_light", sys)
		f.cargo = {"core:resource/ore": 50000}
		victims.append(f.id)
	Pirates.tick(s)
	var lost := victims.filter(func(id: int) -> bool: return s.units.get_or(id) == null).size()
	assert_between(lost, 1, 19, "about half detected at 500 permille")
	assert_eq(_human(s).losses.size(), lost)
	assert_eq(_human(s).losses[0]["cargo"], {"core:resource/ore": 50000}, "cargo lost with the ship")
	var survivors_before := 20 - lost
	Pirates.tick(s)
	var lost_again := victims.filter(func(id: int) -> bool: return s.units.get_or(id) == null).size()
	assert_eq(lost_again, lost, "one roll per passage, not per hour")
	assert_eq(survivors_before, 20 - lost)


func test_raider_leaves_when_its_time_is_up() -> void:
	var s := _match()
	var sys := _own_at(s, 3)
	var u := Pirates.spawn_raider(s, sys, _human(s).id)
	s.pirate_bases[sys] = 99  # a base already here: this raider can't found another
	u.months_left = 1
	Pirates.month_tick(s)
	assert_null(s.units.get_or(u.id))


func test_base_sends_out_raiders() -> void:
	var s := _match()
	var sys := _own_at(s, 3)
	s.pirate_bases[sys] = 1
	Pirates.month_tick(s)
	assert_gte(Pirates.raiders_hunting(s, _human(s).id), 1)


func test_raiders_move_toward_freight() -> void:
	var s := _match()
	var a := _own_at(s, 3)
	var b := -1
	var dist := AutoLogistics._hops_from(s, _home_sys(s), {})
	for lid in s.galaxy.system(a).lane_ids:
		var n := s.galaxy.lane(lid).other_end(a)
		if dist.get(n, 0) >= 3:
			b = n
			break
	if b == -1:
		pass_test("no frontier neighbour on this map")
		return
	s.galaxy.system(b).owner = _human(s).id
	var u := Pirates.spawn_raider(s, a, _human(s).id)
	s.pirate_bases[a] = 99
	Shipyards.spawn(s, _human(s).id, "core:hull/freighter_light", b)
	Pirates._hunt(s, u, {})
	assert_eq(u.path, [b] as Array[int])


## B8 route safety: a loaded auto job whose destination is cut off by a raider takes its cargo back home.
func test_blocked_delivery_returns_cargo_to_source() -> void:
	var s := _match()
	var eid := _human(s).id
	var earth := s.colony(_human(s).capital_planet)
	var far := _own_at(s, 1)
	var pid: int = s.galaxy.system(far).planet_ids[0]
	var site := Colony.new()
	site.id = pid
	site.owner = eid
	s.colonies.put(pid, site)
	Pirates.spawn_raider(s, far, eid)
	assert_true(Freight.blocked(s, eid, _home_sys(s), far), "the raider sits in the target system")
	assert_false(Freight.blocked(s, eid, _home_sys(s), _home_sys(s)))
	var f: Unit = s.units.values().filter(func(u: Unit) -> bool: return u.kind == "freighter" and u.owner == eid)[0]
	var before := earth.stockpile.milli("core:resource/alloys")
	f.cargo = {"core:resource/alloys": 5000}
	f.job = {"source": earth.id, "dest": pid, "resource": "core:resource/alloys", "amount": 5000}
	f.phase = "to_dest"
	f.system_id = _home_sys(s)
	f.body = earth.id
	f.path = []
	f.wait_hours = 0
	for h in 72:
		s.clear_scratch()
		Freight.tick(s)
	assert_eq(f.cargo_milli(), 0, "unloaded")
	assert_true(f.job.is_empty(), "job given back")
	assert_eq(earth.stockpile.milli("core:resource/alloys"), mini(before + 5000, Holders.cap_milli(s, earth.id, "core:resource/alloys")),
		"the alloys went back to their source")
	assert_eq(f.system_id, _home_sys(s), "never flew into the raider")


func test_no_job_into_a_raided_system() -> void:
	var s := _match()
	var eid := _human(s).id
	var far := _own_at(s, 1)
	var pid: int = s.galaxy.system(far).planet_ids[0]
	var site := Colony.new()
	site.id = pid
	site.owner = eid
	s.colonies.put(pid, site)
	s.sectors.clear()
	Pirates.spawn_raider(s, far, eid)
	var d := Demand.new()
	d.id = s.alloc_id()
	d.owner = eid
	d.holder = pid
	d.resource = "core:resource/alloys"
	d.target = 50
	d.priority = 3
	s.demands.put(d.id, d)
	s.clear_scratch()
	AutoLogistics.day_tick(s)
	for u: Unit in s.units.values():
		assert_true(u.job.is_empty() or int(u.job["dest"]) != pid, "nobody is sent into the raider")
