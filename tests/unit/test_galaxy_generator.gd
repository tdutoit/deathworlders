extends GutTest
# M1 WP7: galaxy generation. Seed counts are kept small for test time; tools/galaxy_stress.gd runs
# the full 500 seeds x 4 sizes.

const SIZES: Array[String] = ["small", "medium", "large", "huge"]
const FOUR := ["human", "vesskar", "krothi", "thessari"]

var _db: DefDatabase


func before_all() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	_db = loader.db


func _settings(size: String, species: Array = FOUR) -> MatchSettings:
	var s := MatchSettings.new()
	s.galaxy_size = "core:match_preset/size_" + size
	for i in species.size():
		s.add_player(i, "core:species/" + species[i], "human" if i == 0 else "ai")
	return s


func _gen(size: String, seed_value: int, species: Array = FOUR) -> MatchState:
	var errors: Array[String] = []
	var state := GalaxyGenerator.new_match(_settings(size, species), seed_value, _db, errors)
	assert_eq(errors, [] as Array[String])
	return state


func _hops(g: Galaxy, start: int) -> Dictionary:
	var dist := {start: 0}
	var queue := [start]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		for lid in g.system(at).lane_ids:
			var next := g.lane(lid).other_end(at)
			if not dist.has(next):
				dist[next] = dist[at] + 1
				queue.append(next)
	return dist


func test_same_seed_same_galaxy() -> void:
	for seed_value in 100:
		assert_eq(_gen("small", seed_value).checksum(), _gen("small", seed_value).checksum(), "seed %d" % seed_value)
	for size in SIZES:
		assert_eq(_gen(size, 7).checksum(), _gen(size, 7).checksum(), size)


func test_different_seeds_differ() -> void:
	assert_ne(_gen("small", 1).checksum()["galaxy"], _gen("small", 2).checksum()["galaxy"])


func test_system_counts_match_presets() -> void:
	for size in SIZES:
		var preset: MatchPresetDef = _db.get_def(StringName("core:match_preset/size_" + size))
		var g := _gen(size, 3).galaxy
		assert_eq(g.systems.size(), preset.target_systems, size)
		assert_eq(g.clusters.size(), preset.cluster_count, size)
		for cid: int in g.clusters:
			assert_between(g.cluster(cid).system_ids.size(), 5, 15)


func test_graph_connected_and_well_formed() -> void:
	for size in SIZES:
		var seeds := 40 if size == "small" else 8
		for seed_value in seeds:
			var g := _gen(size, 1000 + seed_value).galaxy
			var first: int = g.systems.keys()[0]
			assert_eq(_hops(g, first).size(), g.systems.size(), "%s seed %d connected" % [size, seed_value])
			for lid: int in g.lanes:
				var l := g.lane(lid)
				assert_true(l.a < l.b and l.length > 0)
				var cross := g.system(l.a).cluster_id != g.system(l.b).cluster_id
				assert_eq(cross, lid in g.corridors, "corridor flag for lane %d" % lid)


func test_in_cluster_degree_cap() -> void:
	var worst := 0
	for seed_value in 20:
		var g := _gen("medium", seed_value).galaxy
		for sid: int in g.systems:
			var in_cluster := 0
			for lid in g.system(sid).lane_ids:
				if not lid in g.corridors:
					in_cluster += 1
			worst = maxi(worst, in_cluster)
	assert_lte(worst, GalaxyGenerator.MAX_LANE_DEGREE)


func test_capital_spacing() -> void:
	for size in SIZES:
		var preset: MatchPresetDef = _db.get_def(StringName("core:match_preset/size_" + size))
		for seed_value in 5:
			var s := _gen(size, 50 + seed_value)
			var caps: Array[int] = []
			for eid: int in s.empires:
				caps.append(s.galaxy.planet((s.empires.get_or(eid) as Empire).capital_planet).system_id)
			assert_eq(caps.size(), 4)
			for i in caps.size():
				var hops := _hops(s.galaxy, caps[i])
				for j in range(i + 1, caps.size()):
					assert_gte(hops[caps[j]], preset.capital_min_jumps, "%s seed %d" % [size, seed_value])


func test_sol_layout() -> void:
	for seed_value in 10:
		var s := _gen("small", seed_value)
		var sol: StarSystem = null
		for sid: int in s.galaxy.systems:
			if s.galaxy.system(sid).name == "Sol":
				assert_null(sol, "only one Sol")
				sol = s.galaxy.system(sid)
		assert_not_null(sol)
		assert_eq(sol.star_type, "core:star_type/yellow")
		var bodies := {}
		for pid in sol.planet_ids:
			var p := s.galaxy.planet(pid)
			bodies[p.name] = p
		assert_eq(bodies.size(), SolTemplate.BODIES.size())
		var earth: Planet = bodies["Earth"]
		assert_eq([earth.planet_type, earth.size], ["core:planet_type/terran", "large"])
		assert_eq(bodies["Mars"].planet_type, "core:planet_type/desert")
		assert_eq(bodies["Venus"].planet_type, "core:planet_type/toxic")
		assert_eq([bodies["Titan"].planet_type, bodies["Titan"].size], ["core:planet_type/arctic", "small"])
		assert_eq(bodies["Luna"].parent_id, earth.id)
		assert_eq(bodies["Titan"].parent_id, bodies["Saturn"].id)
		assert_eq(bodies["Asteroid Belt"].planet_type, "core:planet_type/asteroid_belt")
		var human: Empire = s.empires.get_or(s.empires.keys()[0])
		assert_eq(human.capital_planet, earth.id)
		assert_eq(earth.owner, human.id)
		assert_eq(sol.owner, human.id)


func test_standard_homeworlds() -> void:
	var s := _gen("small", 11)
	for eid: int in s.empires:
		var e: Empire = s.empires.get_or(eid)
		var species: SpeciesDef = _db.get_def(StringName(e.species))
		var cap := s.galaxy.planet(e.capital_planet)
		assert_eq(cap.owner, e.id)
		if species.home_template == &"standard":
			assert_eq(cap.planet_type, String(species.home_planet_type))
			assert_eq(cap.size, "large")


func test_planets_and_names() -> void:
	var g := _gen("large", 21).galaxy
	var names := {}
	for sid: int in g.systems:
		var sys := g.system(sid)
		assert_gt(sys.planet_ids.size(), 0, sys.name)
		assert_false(names.has(sys.name), "duplicate system name " + sys.name)
		names[sys.name] = true
	for pid: int in g.planets:
		var p := g.planet(pid)
		assert_true(_db.has(StringName(p.planet_type)))
		assert_true(p.size in PlanetTypeDef.SIZES)
		for res: String in p.deposits:
			assert_true(_db.has(StringName(res)))
			assert_between(p.deposits[res], 1, 3)


func test_huge_is_fast() -> void:
	var t0 := Time.get_ticks_msec()
	_gen("huge", 5, FOUR + ["ohlan", "human", "krothi", "vesskar"])
	assert_lt(Time.get_ticks_msec() - t0, 2000, "Huge galaxy < 2 s headless")


func test_bad_settings_are_reported() -> void:
	var s := _settings("small", ["human", "dragon"])
	s.pace = "core:match_preset/size_small"
	var errors: Array[String] = []
	assert_null(GalaxyGenerator.new_match(s, 1, _db, errors))
	assert_eq(errors.size(), 2, "\n".join(errors))


func test_replay_from_seed() -> void:
	var settings := _settings("small")
	var s := _gen("small", 404)
	var human: Empire = s.empires.get_or(s.empires.keys()[0])
	var home := s.galaxy.planet(human.capital_planet).system_id
	var far: int = s.galaxy.systems.keys()[-1]
	var sched := CommandSchedule.new()
	sched.submit(CommandRegistry.create(CmdDebugSpawnScout.TYPE, human.id, {"system": home}), 0)
	for t in 200:
		if t == 3:
			var scout: int = s.units.keys()[0]
			sched.submit(CommandRegistry.create(CmdMoveUnit.TYPE, human.id, {"unit": scout, "to": far}), s.tick)
		Sim.step(s, sched.take_due(s.tick))
	var scout_unit: Unit = s.units.values()[0]
	assert_ne(scout_unit.system_id, home, "the scout went somewhere")
	assert_eq(Sim.replay(404, settings, _db, s.command_log, s.tick).checksum(), s.checksum())
