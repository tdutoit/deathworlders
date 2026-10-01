extends GutTest
# M1 WP4: state model round-trips and per-subsystem checksums.


## A small hand-built match: 1 cluster, 2 systems joined by a lane, 2 planets, 1 empire, 1 scout.
static func build_sample() -> MatchState:
	var settings := MatchSettings.new()
	settings.seed_text = "Sol forever"
	settings.add_player(0, "core:species/human", "human")
	var s := MatchState.create(settings, DetRng.match_seed_from_text(settings.seed_text))
	var g := s.galaxy
	var c := Cluster.new()
	c.id = s.alloc_id()
	c.name = "Orion Reach"
	c.x = -120
	c.y = 340
	g.clusters.put(c.id, c)
	var systems: Array[StarSystem] = []
	for i in 2:
		var sys := StarSystem.new()
		sys.id = s.alloc_id()
		sys.name = "System %d" % i
		sys.cluster_id = c.id
		sys.x = c.x + i * 50
		sys.y = c.y - i * 30
		sys.star_type = "core:star_type/yellow"
		g.systems.put(sys.id, sys)
		c.system_ids.append(sys.id)
		systems.append(sys)
	var lane := Hyperlane.new()
	lane.id = s.alloc_id()
	lane.a = systems[0].id
	lane.b = systems[1].id
	lane.length = 58
	g.lanes.put(lane.id, lane)
	systems[0].lane_ids.append(lane.id)
	systems[1].lane_ids.append(lane.id)
	for i in 2:
		var p := Planet.new()
		p.id = s.alloc_id()
		p.system_id = systems[0].id
		p.name = "Planet %d" % i
		p.planet_type = "core:planet_type/terran" if i == 0 else "core:planet_type/gas_giant"
		p.size = "large" if i == 0 else "huge"
		p.orbit_index = i
		p.orbit_radius = 100 + i * 80
		p.deposits = {"core:resource/ore": 40, "core:resource/food": 25}
		p.orbital_slots = 3
		g.planets.put(p.id, p)
		systems[0].planet_ids.append(p.id)
	var e := Empire.new()
	e.id = s.alloc_id()
	e.species = "core:species/human"
	e.player_slot = 0
	e.capital_planet = systems[0].planet_ids[0]
	e.color = "#3b5b92"
	s.empires.put(e.id, e)
	systems[0].owner = e.id
	g.planet(e.capital_planet).owner = e.id
	var u := Unit.new()
	u.id = s.alloc_id()
	u.owner = e.id
	u.kind = "scout"
	u.system_id = systems[0].id
	u.path = [systems[1].id]
	u.progress = 7
	u.speed = 4
	s.units.put(u.id, u)
	s.rng(DetRng.GALAXY).next_u32()  # advance one stream so rng state is non-trivial
	s.tick = 1234
	return s


func test_round_trip_keeps_checksum() -> void:
	var s := build_sample()
	var copy := MatchState.from_dict(s.to_dict())
	assert_eq(copy.checksum(), s.checksum())
	assert_eq(copy.to_dict(), s.to_dict())


func test_json_round_trip_keeps_checksum() -> void:
	# Saves go through JSON (WP10); numbers come back as floats and must be re-cast to ints.
	var s := build_sample()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	assert_eq(MatchState.from_dict(parsed).checksum(), s.checksum())


func test_round_trip_preserves_rng_sequence() -> void:
	var s := build_sample()
	var copy := MatchState.from_dict(s.to_dict())
	for stream in MatchState.RNG_STREAMS:
		assert_eq(copy.rng(stream).next_u32(), s.rng(stream).next_u32(), stream)


func test_checksum_parts_pinpoint_changes() -> void:
	var s := build_sample()
	var before := s.checksum()
	var unit: Unit = s.units.values()[0]
	unit.progress += 1
	var after := s.checksum()
	assert_ne(after["units"], before["units"])
	assert_ne(after["total"], before["total"])
	for part in ["meta", "galaxy", "empires", "rng"]:
		assert_eq(after[part], before[part], part + " unchanged")


func test_each_subsystem_is_covered() -> void:
	var s := build_sample()
	var base := s.checksum()
	s.tick += 1
	assert_ne(s.checksum()["meta"], base["meta"])
	s.galaxy.system(s.galaxy.systems.keys()[0]).owner = 0
	assert_ne(s.checksum()["galaxy"], base["galaxy"])
	(s.empires.values()[0] as Empire).color = "#000000"
	assert_ne(s.checksum()["empires"], base["empires"])
	s.rng(DetRng.COMBAT).next_u32()
	assert_ne(s.checksum()["rng"], base["rng"])


func test_same_inputs_same_checksum() -> void:
	assert_eq(build_sample().checksum(), build_sample().checksum())


func test_ids_are_monotonic() -> void:
	var s := MatchState.create(MatchSettings.new(), 1)
	assert_eq(s.alloc_id(), 1)
	assert_eq(s.alloc_id(), 2)
	assert_eq(s.next_id, 3)


func test_streams_seeded_from_match_seed() -> void:
	var s := MatchState.create(MatchSettings.new(), 42)
	assert_eq(s.rng(DetRng.GALAXY).get_state(), DetRng.from_seed(42, DetRng.GALAXY).get_state())
	assert_eq(s.rng_streams.keys(), ["ai", "combat", "events", "galaxy", "misc"])


func test_lane_between() -> void:
	var s := build_sample()
	var ids: Array = s.galaxy.systems.keys()
	assert_not_null(s.galaxy.lane_between(ids[0], ids[1]))
	assert_not_null(s.galaxy.lane_between(ids[1], ids[0]))
	assert_null(s.galaxy.lane_between(ids[0], 999))
