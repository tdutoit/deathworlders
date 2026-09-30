extends GutTest
# M1 WP2: DetRng behaviour beyond the reference vectors.


func test_state_round_trip_resumes_sequence() -> void:
	var a := DetRng.from_seed(123, DetRng.GALAXY)
	for i in 5:
		a.next_u32()
	var b := DetRng.new()
	b.set_state(a.get_state())
	for i in 20:
		assert_eq(b.next_u32(), a.next_u32())


func test_streams_are_independent() -> void:
	var galaxy := DetRng.from_seed(1, DetRng.GALAXY)
	var combat := DetRng.from_seed(1, DetRng.COMBAT)
	assert_ne(galaxy.get_state(), combat.get_state())


func test_all_zero_state_is_repaired() -> void:
	var rng := DetRng.new(0, 0, 0, 0)
	assert_eq(rng.get_state(), [1, 0, 0, 0] as Array[int])
	assert_ne(rng.next_u32() | rng.next_u32() | rng.next_u32(), 0)


func test_mod_stream_name() -> void:
	assert_eq(DetRng.mod_stream("better_railguns"), "mod:better_railguns")


func test_range_bounds() -> void:
	var rng := DetRng.from_seed(99, DetRng.MISC)
	for i in 2000:
		var r := rng.range(-3, 4)
		assert_between(r, -3, 3)
		if r < -3 or r > 3:
			return
	assert_eq(rng.range(5, 6), 5, "single-value range")


func test_roll_permille_bounds() -> void:
	var rng := DetRng.from_seed(5, DetRng.EVENTS)
	var lo := 1000
	var hi := -1
	for i in 5000:
		var r := rng.roll_permille()
		lo = mini(lo, r)
		hi = maxi(hi, r)
	assert_gte(lo, 0)
	assert_lte(hi, 999)


# Rough uniformity check: chi-square over 100k rolls into 10 buckets. Fixed seed, so it's
# deterministic; 27.88 is the p = 0.001 critical value for 9 degrees of freedom.
func test_range_distribution_chi_square() -> void:
	const BUCKETS := 10
	const ROLLS := 100000
	var rng := DetRng.from_seed(2026, DetRng.AI)
	var counts: Array[int] = []
	counts.resize(BUCKETS)
	counts.fill(0)
	for i in ROLLS:
		counts[rng.range(0, BUCKETS)] += 1
	var expected := float(ROLLS) / BUCKETS
	var chi2 := 0.0
	for c in counts:
		chi2 += (c - expected) * (c - expected) / expected
	assert_lt(chi2, 27.88, "chi-square %.2f, counts %s" % [chi2, counts])
