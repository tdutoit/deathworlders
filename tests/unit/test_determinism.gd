extends GutTest
# M1 WP11: a short determinism harness case inside the suite. The full run (20 seeds x 4 sizes x
# 5 years) is tools/determinism_test.gd.


func test_short_harness_case_is_deterministic() -> void:
	var loader := ContentLoader.new()
	loader.load_mods([])
	var harness := DeterminismHarness.new(loader.db, loader.manifests)
	harness.save_dir = "user://test_determinism"
	DirAccess.make_dir_recursive_absolute(harness.save_dir)
	var result := harness.run_case("small", 4242, 6)
	assert_true(result["ok"], result["message"])
	assert_eq(result["checksums"].size(), 6, "one checksum set per month")


func test_harness_detects_divergence() -> void:
	# Two different seeds must not compare equal: guards against a harness that always says OK.
	var loader := ContentLoader.new()
	loader.load_mods([])
	var harness := DeterminismHarness.new(loader.db, loader.manifests)
	harness.save_dir = "user://test_determinism"
	var a: Array = harness.run_case("small", 1, 1)["checksums"]
	var b: Array = harness.run_case("small", 2, 1)["checksums"]
	assert_ne(a[0]["galaxy"], b[0]["galaxy"])


func test_pathfinder_heap_matches_known_routes() -> void:
	# Same expectations as the WP6 tests, now on the heap implementation, plus a tie: two equal
	# 2-lane routes 1-2-4 and 1-3-4 must pick the lower intermediate system ID.
	var s := MatchState.create(MatchSettings.new(), 1)
	for i in 4:
		var sys := StarSystem.new()
		sys.id = s.alloc_id()
		s.galaxy.systems.put(sys.id, sys)
	for pair: Array in [[1, 3, 5], [3, 4, 5], [1, 2, 5], [2, 4, 5]]:
		var l := Hyperlane.new()
		l.id = s.alloc_id()
		l.a = pair[0]
		l.b = pair[1]
		l.length = pair[2]
		s.galaxy.lanes.put(l.id, l)
		s.galaxy.system(l.a).lane_ids.append(l.id)
		s.galaxy.system(l.b).lane_ids.append(l.id)
	assert_eq(Pathfinder.route(s.galaxy, 1, 4), [2, 4] as Array[int])
	assert_eq(Pathfinder.route(s.galaxy, 4, 1), [2, 1] as Array[int])
